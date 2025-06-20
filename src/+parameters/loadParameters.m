function [ScopeParameters, Options] = loadParameters(Options, use_xlsx, ExcelData, ForcingData, scopeInput)
    Options.Cca_function_of_Cab = 0;

    % for 'm', see # 64, below for intercept: 'BallBerry0'
    % 'Cant' Added March 2017
    % 'BallBerry0' acccidentally left out of v1.7
    ScopeParametersNames = {
                            'Cab', 'Cca', 'Cdm', 'Cw', 'Cs', 'N', 'rho_thermal', 'tau_thermal', ...
                            'Vcmo', 'm', 'Type', 'kV', 'Rdparam', 'Tparam', 'fqe', 'spectrum', ...
                            'rss', 'rs_thermal', 'cs', 'rhos', 'lambdas', 'LAI', 'hc', 'zo', 'd', ...
                            'LIDFa', 'LIDFb', 'leafwidth', 'z', 'Rin', 'Ta', 'Rli', 'p', 'ea', 'u', ...
                            'Ca', 'Oa', 'rb', 'Cd', 'CR', 'CD1', 'Psicor', 'CSSOIL', 'rbs', 'rwc', ...
                            'startDOY', 'endDOY', 'LAT', 'LON', 'timezn', 'tts', 'tto', 'psi', 'SMC', ...
                            'Tyear', 'beta', 'kNPQs', 'qLs', 'stressfactor', 'Cant', 'BSMBrightness', ...
                            'BSMlat', 'BSMlon', 'BallBerry0'
                           };

    % create an empty structure with field names of ScopeParametersNames
    % ScopeParameters = cell2struct(cell(1, length(ScopeParametersNames)), ScopeParametersNames, 2);
    ScopeParameters = cell2struct(repmat({[]}, 1, length(ScopeParametersNames)), ScopeParametersNames, 2);
    for i = 1:length(ScopeParametersNames)
        name = ScopeParametersNames{i};
        logical_j = strcmp(strtok(ExcelData(:, 1)), name);
        j = find(logical_j);

        cond = false; % 默认不缺失
        if ~isempty(j) % 确保 j 存在，避免索引错误
            if ~use_xlsx
                % 确保 j+1 不超出 scopeInput 的范围
                if (j + 1) <= numel(scopeInput)
                    cond = isnan(scopeInput(j + 1));
                else
                    cond = true; % 如果索引超出范围，也认为是缺失
                end
            else
                % 确保 j 不超出 scopeInput 的行范围
                if j <= size(scopeInput, 1)
                    cond = sum(~isnan(scopeInput(j, :))) < 1;
                else
                    cond = true; % 如果索引超出范围，也认为是缺失
                end
            end
        end

        if isempty(j) || cond
            if strcmp(name, 'Cab')
                warning('warning: input "%s" not provided in input spreadsheet...I will use 0.25*Cab instead', name);
                Options.Cca_function_of_Cab = 1;
            elseif ~(Options.simulation == 1) && (strcmp(name, 'Rin') || strcmp(name, 'Rli'))
                warning('warning: input "%s" not provided in input spreadsheet... I will use the MODTRAN spectrum as it is', name);
            elseif Options.simulation == 1 || (Options.simulation ~= 1 && (i < 46 || i > 50))
                warning('warning: input "%s" not provided in input spreadsheet', name);
                if Options.simulation == 1 && (strcmp(name, 'Cab') || strcmp(name, 'Vcmo') || strcmp(name, 'LAI') || strcmp(name, 'hc') || strcmp(name, 'SMC') || (i > 29 && i < 37))
                    fprintf(1, '%s %s %s\n', 'I will look for the values in Dataset Directory "', char(ForcingData(5).FileName), '"');
                elseif strcmp(name, 'zo') || strcmp(name, 'd')
                    fprintf(1, '%s %s %s\n', 'will estimate it from LAI, CR, CD1, Psicor, and CSSOIL');
                    Options.calc_zo = 1;
                elseif i > 38 && i < 44
                    fprintf(1, '%s %s %s\n', 'will use the provided zo and d');
                    Options.calc_zo = 0;
                elseif ~(Options.simulation == 1 && (strcmp(name, 'Rin') || strcmp(name, 'Rli')))
                    fprintf(1, '%s \n', 'this input is required: SCOPE ends');
                    return
                else
                    fprintf(1, '%s %s %s\n', '... no problem, I will find it in Dataset Directory "', char(ForcingData(5).FileName), '"');
                end
            end
        end
        if ~use_xlsx
            j2 = [];
            j1 = j + 1;
            while 1
                if isnan(scopeInput(j1))
                    break
                end
                j2 = [j2; j1]; %#ok<AGROW>
                j1 = j1 + 1;
            end
            if isempty(j2)
                ScopeParameters.(name)            = -999;
            else
                ScopeParameters.(name)            = scopeInput(j2);
            end
        else
            if sum(~isnan(scopeInput(j, :))) < 1
                ScopeParameters.(name)            = -999;
            else
                ScopeParameters.(name)           = scopeInput(j, ~isnan(scopeInput(j, :)));
            end
        end
    end
end
