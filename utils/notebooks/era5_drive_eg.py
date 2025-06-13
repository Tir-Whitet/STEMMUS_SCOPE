#!C:\Users\Ajie\anaconda3\envs\scope\python.exe
# coding=utf-8
'''
@File    :  era5_drive_eg.py
@Time    :  2025/06/06 11:34
@Author  :  Ajie 
@Email   :   
@Version :  1.0
--------------------------------------------
@Desc    :  原始代码来源`download_era5_data.ipynb`
            此处仅做整理, 以便后续重复使用方便   
            本函数最好运行于scope环境中(已安装era5cli)         
'''
# from netCDF4 import Dataset, num2date
from pathlib import Path
import xarray as xr
import numpy as np
import era5cli
import subprocess
import pandas as pd

# %pip install era5cli
# %era5cli config --key "KEY"  # 不含引号

land_sea_filename = Path("./lsm_1279l4_0.1x0.1.grb_v4_unpack.nc")
forcing_path = Path("E:/Work/2505/SCOPE/STEMMUS_SCOPE/utils/notebooks/")


# region # 给定驱动数据，下载土壤温湿度和LST
# Functions to Select data in era5-land
def find_nearest_ERA5_land_point(lsm_dataset, point_longitude, point_latitude, padding):
    """Find nearest grid cell in land see mask to a point based on Geographical distances.
    返回离目标点最近的陆地网格点的经纬度坐标
    args:
        lsm_dataset: ERA5 land sea mask dataset
        point_longitude: longitude in degrees of target coordinate
        point_latitude: latitude in degrees of target coordinate
        padding: bounding box around the point
    returns:
        longitude: longitude of closest grid cell
        latitude: latitude of closest grid cell
    """
    # create a bounding_box 
    lat_max = point_latitude + padding
    lat_min = point_latitude - padding
    lon_max = point_longitude + padding
    lon_min = point_longitude - padding

    lsm_lon = lsm_dataset["longitude"].values
    lsm_lat = lsm_dataset["latitude"].values
    longitudes = lsm_lon[(lsm_lon >= lon_min) & (lsm_lon <= lon_max)]
    latitudes = lsm_lat[(lsm_lat >= lat_min) & (lsm_lat <= lat_max)]
    bounding_box = lsm_dataset.sel(longitude=longitudes, latitude=latitudes)

    grid_longitudes_array = np.array(bounding_box["longitude"].values)
    grid_latitudes_array = np.array(bounding_box["latitude"].values)

    # Create a grid from coordinates (shape will be (nlat, nlon))
    lon_vectors, lat_vectors = np.meshgrid(grid_longitudes_array, grid_latitudes_array)

    # calculate distanced
    distances = geographical_distances(
        point_longitude, point_latitude, lon_vectors, lat_vectors
    )

    # mask distances where they are on sea: values less than 0.6
    masked_distances = xr.where(bounding_box >= 0.6, distances, np.nan)

    # find the nearest on land
    index = np.nanargmin(masked_distances["lsm"].to_numpy())
    idx_lat, idx_lon = np.unravel_index(index, distances.shape)
    
    selected_grid = bounding_box.isel(longitude=int(idx_lon), latitude=int(idx_lat))
    
    return selected_grid["longitude"].values, selected_grid["latitude"].values


def geographical_distances(point_longitude, point_latitude, lon_vectors, lat_vectors, radius=6373.0,):
    """It uses Spherical Earth projected to a plane formula:
    https://en.wikipedia.org/wiki/Geographical_distance
    计算一个目标点与一组地理坐标点之间的近似地理距离(km)使用的是“球形地球投影到平面”的简化公式
    args:
        point_longitude: longitude in degrees of target coordinate
        point_latitude: latitude in degrees of target coordinate
        lon_vectors: 1d array of longitudes in degrees
        lat_vectors: 1d array of latitudes in degrees
        radius: Radius of a sphere in km. Default is Earths approximate radius.
    returns:
        distances: array of geographical distance of point to all vector members
    """
    dlon = np.radians(lon_vectors - point_longitude)
    dlat = np.radians(lat_vectors - point_latitude)
    latm = np.radians((lat_vectors + point_latitude) / 2)
    return radius * np.sqrt(dlat**2 + (np.cos(latm) * dlon) ** 2)


def convert_lon(ds, lon_name):
    """Adjust lon values to make sure they are within (-180, 180).
    args: 
        ds: xarray dataset
        lon_name: whatever name is in the data
    returns: 
        ds: xarray dataset
    """
    ds['_longitude_adjusted'] = xr.where(
        ds[lon_name] > 180,
        ds[lon_name] - 360,
        ds[lon_name])

    # reassign the new coords to as the main lon coords
    # and sort DataArray using new coordinate values
    ds = (
        ds
        .swap_dims({lon_name: '_longitude_adjusted'})
        .sel(**{'_longitude_adjusted': sorted(ds._longitude_adjusted)})
        .drop(lon_name))

    ds = ds.rename({'_longitude_adjusted': lon_name})
    return ds


def get_forcing_info(ds):
    # 要求forcingdata中存在; 即使处理网格数组也只返回经纬度的起始值
    # 适用于站点
    lon = ds["longitude"].values.flatten()[0]
    lat = ds["latitude"].values.flatten()[0]
    time = ds["time"].dt
    return lon, lat, time

# landsea掩膜已存在无需重复下载，复用即可
land_sea_filename = 'E:/Work/2505/SCOPE/STEMMUS_SCOPE/utils/notebooks/lsm_1279l4_0.1x0.1.grb_v4_unpack.nc'
lsm = xr.open_dataset(land_sea_filename)
lsm_dataset = convert_lon(lsm, 'longitude')

def era5_download(forcing):
    """
    根据forcing信息下载ERA5数据; 封装了原始处理部分
    参数:
    forcing: 包含时间、经纬度信息的forcings数据。
    forcing_name: 用于生成文件名的forcing名称。
    """
    lon, lat, time = get_forcing_info(forcing)    
    nearest_lon, nearest_lat = find_nearest_ERA5_land_point(lsm_dataset, lon, lat, 0.2)
    
    startyear = time.year.values[0]
    endyear = startyear
    startmonth = time.month.values[0]
    startday = time.day.values[0]
    starthour = time.hour.values[0]
    
    lat_max = nearest_lat + 0.001
    lat_min = nearest_lat - 0.001
    lon_max = nearest_lon + 0.001
    lon_min = nearest_lon - 0.001
    
    station_name = forcing_name.split('_')[0]
    # 确保时间戳格式正确，特别是当time不是pandas Timestamp类型时
    if isinstance(time.values[0], pd.Timestamp):
        timestamp = time.values[0].strftime('%Y%m%d_%H')
    else:
        # 如果time不是pandas Timestamp，尝试转换为datetime对象再格式化
        import datetime
        dt_object = datetime.datetime(time.year.values[0], time.month.values[0], 
                                      time.day.values[0], time.hour.values[0])
        timestamp = dt_object.strftime('%Y%m%d_%H')
        
    file_name = f"{station_name}_{timestamp}"

    # ERA5cli 命令
    command = [
        "era5cli", "hourly",
        "--variables", 
        "soil_temperature_level_1", "soil_temperature_level_2", 
        "soil_temperature_level_3", "soil_temperature_level_4",
        "volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2", 
        "volumetric_soil_water_layer_3", "volumetric_soil_water_layer_4", 
        "skin_temperature",
        "--startyear", str(startyear),
        "--endyear", str(endyear),
        "--land",
        "--area", str(lat_max), str(lon_min), str(lat_min), str(lon_max),
        "--months", str(startmonth),
        "--days", str(startday),
        "--hours", str(starthour),
        "--outputprefix", file_name,
        "--merge"
    ]

    print(f"执行ERA5cli命令: {' '.join(command)}")
    
    try:
        # 使用subprocess.run执行命令
        # capture_output=True 可以捕获ERA5cli的输出
        # text=True 会将输出解码为文本
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("ERA5cli命令执行成功！")
        if result.stdout:
            print("ERA5cli标准输出:")
            print(result.stdout)
        if result.stderr:
            print("ERA5cli标准错误 (如果有):")
            print(result.stderr)
    except subprocess.CalledProcessError as e:
        print(f"ERA5cli命令执行失败，错误代码: {e.returncode}")
        print(f"标准输出: {e.stdout}")
        print(f"标准错误: {e.stderr}")
        raise # 重新抛出异常，以便调用者可以处理
    except FileNotFoundError:
        print("错误: 'era5cli' 命令未找到。请确保ERA5cli已正确安装并添加到系统PATH中。")
        raise
    except Exception as e:
        print(f"执行ERA5cli时发生未知错误: {e}")
        raise
        
    print('Done!')
# endregion


forcing_name = 'AR-SLu_2010-2010_FLUXNET2015_Met.nc'
forcing = xr.open_dataset(forcing_path / forcing_name)
