function [DeltZ, DeltZ_R, NL, ML_final] = Dtrmn_Z(NL_input, Tot_Depth)
    %{
        The determination of the element length
        (Genimi) NL: 初始的层数（可能是一个最大层数或预期层数）。
                 Tot_Depth：总深度。
    %}
    DeltZ_R = zeros(1, NL_input); % 预分配为行向量

    % 使用一个新变量来跟踪循环迭代，避免修改循环索引
    % current_ML = 0; % 用于跟踪当前的层索引
    % --- 硬编码前42层的厚度 ---
    % 使用向量化赋值替代循环，提高效率    
    % ML = 1:3, DeltZ_R = 1
    current_ML = 3;
    DeltZ_R(1:current_ML) = 1;
    % ML = 4, DeltZ_R = 2
    current_ML = current_ML + 1;
    DeltZ_R(current_ML) = 2;
    % ML = 5:14, DeltZ_R = 2
    start_idx = current_ML + 1;
    current_ML = 14;
    DeltZ_R(start_idx:current_ML) = 2;
    % ML = 15:18, DeltZ_R = 2.5
    start_idx = current_ML + 1;
    current_ML = 18;
    DeltZ_R(start_idx:current_ML) = 2.5;
    % ML = 19:23, DeltZ_R = 5
    start_idx = current_ML + 1;
    current_ML = 23;
    DeltZ_R(start_idx:current_ML) = 5;
    % ML = 24:31, DeltZ_R = 10
    start_idx = current_ML + 1;
    current_ML = 31;
    DeltZ_R(start_idx:current_ML) = 10;    
    % ML = 32:40, DeltZ_R = 10 (这里可能和上面重复，但保留原逻辑)
    start_idx = current_ML + 1;
    current_ML = 40;
    DeltZ_R(start_idx:current_ML) = 10;
    % ML = 41:42, DeltZ_R = 15
    start_idx = current_ML + 1;
    current_ML = 42;
    DeltZ_R(start_idx:current_ML) = 15;

    % 累加已分配的层厚度总和
    Elmn_Lnth = sum(DeltZ_R(1:current_ML)); % 只对已赋值的部分求和

    % 初始化输出变量，避免在后续循环中动态增长
    NL = current_ML; % 从已定义的层数开始
    ML_final = current_ML; % 初始的最终 ML 索引

    % --- 处理剩余深度和层数 ---
    % 再次使用新变量作为循环索引，避免修改 ML
    for current_loop_ML = (current_ML + 1):NL_input
        % 检查 DeltZ_R 是否需要扩展以容纳新的层
        if current_loop_ML > length(DeltZ_R)
            DeltZ_R(current_loop_ML) = 0; % 自动扩展数组
        end        
        DeltZ_R(current_loop_ML) = 20; % 剩余的层每层厚度为 20
        Elmn_Lnth = Elmn_Lnth + DeltZ_R(current_loop_ML); % 累加总厚度
        
        if Elmn_Lnth >= Tot_Depth % 如果当前总厚度达到或超过了目标 Tot_Depth
            % 调整最后一层的厚度，使其恰好等于 Tot_Depth
            DeltZ_R(current_loop_ML) = Tot_Depth - (Elmn_Lnth - DeltZ_R(current_loop_ML));
            
            NL = current_loop_ML; % 更新总层数 NL 为当前的 ML 值
            ML_final = current_loop_ML; % 更新最终的 ML 索引
            
            % 预分配 DeltZ
            DeltZ = zeros(1, NL);
            % 反转 DeltZ_R 得到 DeltZ
            for inner_loop_ML = 1:NL
                MML = NL - inner_loop_ML + 1;
                DeltZ(inner_loop_ML) = DeltZ_R(MML);
            end
            return % 找到匹配的层数和厚度后，立即退出函数
        end
    end
    
    % 如果循环完成，但 Elmn_Lnth 仍未达到 Tot_Depth，
    % 这意味着 NL_input 太小了，无法达到 Tot_Depth。
    % 这种情况下，根据原始代码，它会返回当前计算出的 DeltZ_R 和 Elmn_Lnth，
    % 并且 NL 和 ML_final 仍然是 NL_input。
    % 这里可以考虑添加一个警告或错误处理。
    warning('Total depth (%f) not reached with initial NL_input (%d) layers. Current total depth is %f.', Tot_Depth, NL_input, Elmn_Lnth);
    NL = NL_input; % 保持 NL 为输入值
    ML_final = NL_input; % 保持 ML_final 为输入值

    % 在这种情况下，如果 Tot_Depth 没达到，DeltZ_R 会是 NL_input 长度。
    % DeltZ 则需要根据实际的 DeltZ_R 来反转。
    % 如果代码执行到这里，意味着 for current_loop_ML 循环走完了但没 return
    % 也就是说 Elmn_Lnth < Tot_Depth
    % 这时 NL 保持为 NL_input，需要根据 DeltZ_R 的实际赋值部分来生成 DeltZ
    DeltZ = zeros(1, NL);
    for inner_loop_ML = 1:NL
        MML = NL - inner_loop_ML + 1;
        DeltZ(inner_loop_ML) = DeltZ_R(MML);
    end

end
