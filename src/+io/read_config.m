function [InputPath, OutputPath, InitialConditionPath, FullCSVfiles] = read_config(config_file)

    file_id = fopen(config_file);
    config = textscan(file_id, '%s %s', 'HeaderLines', 0, 'Delimiter', '=');
    fclose(file_id);

    %% separate vars and paths
    config_vars = config{1};
    config_paths = config{2};

    %% find the required path by model
    logical_idx = strcmp(config_vars, 'InputPath');
    InputPath = config_paths{logical_idx}; 

    logical_idx = strcmp(config_vars, 'OutputPath');
    OutputPath = config_paths{logical_idx};

    % indx = find(strcmp(config_vars, 'InitialConditionPath'));
    % InitialConditionPath = config_paths{indx};
    logical_idx = strcmp(config_vars, 'InitialConditionPath');
    InitialConditionPath = config_paths{logical_idx};

    % FullCSVfiles
    logical_idx = strcmp(config_vars, 'FullCSVfiles');
    if ~any(logical_idx) % 检查逻辑数组中是否有任何 true (即是否找到了 'FullCSVfiles')
        FullCSVfiles = 1; % 如果没找到，设置为默认值 1
    else
        % 如果找到，使用逻辑数组索引获取值，并转换为数字
        FullCSVfiles = str2double(config_paths{logical_idx}); 
    end
