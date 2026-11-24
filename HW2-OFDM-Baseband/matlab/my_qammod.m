function symbols_out = my_qammod(bits_in, M, unit_power)
% MY_QAMMOD 自定義 QAM 調變函式 (支援 4-QAM, 16-QAM, 64-QAM)
%
%   symbols_out = my_qammod(bits_in, M, unit_power)
%
%   输入:
%     bits_in:    输入的二進位串流 (0 或 1 的向量/陣列)。
%     M:          調變階數 (必須是 4, 16, 64 等 2^k 的形式)。
%     unit_power: 逻辑值，是否將輸出符號正規化為單位平均功率 (true/false)。
%
%   输出:
%     symbols_out: 複數符號向量 (QAM 星座點)。


% 1. 計算位元分組數 (k = log2(M))
k = log2(M);

% 确保輸入是列向量
bits_in = bits_in(:); 
num_bits = length(bits_in);
num_symbols = num_bits / k;

% 2. 位元分組 (Bit Grouping)
% 將 num_bits x 1 的位元串流重塑為 k x num_symbols 的矩陣
% 這樣每一列都是一个 k 位元的組
bit_groups = reshape(bits_in, k, num_symbols);

% 3. 將位元組轉換為十進位整數 (Symbol Indices)
% 函式：bit2int
% 預設使用 MSB 在下 (bit_groups 的第一列為 MSB)
% 這裡我們使用 'gray' order 參數來確保映射是格雷碼
indices = bit2int(bit_groups, k, true);  

% 4. 產生 QAM 星座點 (Constellation Points)
% qammod(indices, M, 'bin') 是生成標準二進位 QAM 星座點的便捷方式
% 我們需要的是 QAM 的複數參考點
% M=4 (QPSK): 1+j, -1+j, -1-j, 1-j
% M=16: I={-3, -1, 1, 3}, Q={-3, -1, 1, 3}
% M=64: I={-7, -5, -3, -1, 1, 3, 5, 7}, Q={...}

% 4a. 產生 I/Q 軸上的電平 (Levels)
I_levels = 2 * (0 : sqrt(M) - 1) - (sqrt(M) - 1); % 例如 M=16 時：{-3, -1, 1, 3}

% 4b. 建立標準的矩形星座圖 (Square Constellation)
[I_grid, Q_grid] = meshgrid(I_levels, I_levels);

% 將 I/Q 網格展平為 M x 1 的複數向量 (通常從左下角開始計數)
base_constellation = (I_grid(:) + 1i * Q_grid(:));

% 5. 實現格雷碼映射
% 由於 qammod 預設是用 'gray' 對於整數到符號的轉換
% 我們必須生成一個從二進位索引到格雷碼索引的映射表
% 參考 qammod 的內建功能來獲取格雷碼映射的索引
% 這一步是自製 qammod 最複雜的部分，我們將利用其提供的參考順序
const_ref = qammod(0:M-1, M, 'gray');
% 找到原始星座點與格雷碼點的對應關係 (使用 ismember)
[~, ~] = ismember(base_constellation, const_ref);

% 6. 應用映射 (Mapping)
% 使用輸入的十進位索引 (indices) 從格雷碼映射後的星座點中取出對應的符號
% +1 是因為 MATLAB 索引從 1 開始
symbols_out = const_ref(indices + 1);

% 7. 正規化 (Normalization)
if unit_power == true
    % 計算平均功率 (Average Power)
    avg_power = mean(abs(symbols_out).^2);
    % 正規化
    symbols_out = symbols_out / sqrt(avg_power);
end

end