function SoilLayerSettings = readSoilLayerSettings(soilLayersFile)
    % soildata = dlmread(soilLayersFile, ',', 1, 0);  % skip column names
    soildata = readmatrix(soilLayersFile, 'Delimiter', ',', 'HeaderLines', 1);

    if isempty(soildata)
        error('无法从文件 %s 中读取土壤层数据，或者文件内容为空。', soilLayersFile);
    end
    if size(soildata, 1) < 1 || size(soildata, 2) < 1
        error('土壤层数据文件 %s 的内容格式不符合预期，至少需要一行一列。', soilLayersFile);
    end

    SoilLayerSettings.NL = soildata(end, 1);
    SoilLayerSettings.ML = SoilLayerSettings.NL;

    if size(soildata, 2) < 2
        error('土壤层数据文件 %s 的内容格式不符合预期，至少需要两列用于 DeltZ_R。', soilLayersFile);
    end
    SoilLayerSettings.DeltZ_R = soildata(:, 2).'; % 使用 .' 进行非共轭转置
    SoilLayerSettings.DeltZ = flip(SoilLayerSettings.DeltZ_R);

    SoilLayerSettings.Tot_Depth = sum(SoilLayerSettings.DeltZ_R);
    if size(soildata, 2) < 3
        error('土壤层数据文件 %s 的内容格式不符合预期，至少需要三列用于 R_depth。', soilLayersFile);
    end
    SoilLayerSettings.R_depth = soildata(1, 3);
end
