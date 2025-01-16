% 实验1：编程实现SFT

close all;
clear;
clc;

% 固定随机数种子
rng(2025);

% 信号长度
N = 2 ^ 12;
% 频谱稀疏度
K = 10;
% 分筐的个数B约为sqrt(NK)，整除N
B = 128;
% 循环次数L=O(logN)
L = ceil(log2(N));
% 定位循环用到的参数d<B/K
d = 4;

if mod(N, B) ~= 0
    error('error! B should divide N.');
end

% 信号频谱S[i]
S_k = zeros(1, N);

% 随机选择K个点赋非零值
nonzero_index = randperm(N, K);

for m = nonzero_index
    % 模长为[0.5,1]内均匀分布
    magnitude = 0.5 + (1 - 0.5) * rand;
    % 辐角为[0,2*pi]内均匀分布
    phase = 2 * pi * rand;
    S_k(m) = magnitude * exp(1j * phase);
end

% 频谱S[i]做IDFT得时域信号s[n]
s_n = ifft(S_k, N);
x_n = s_n;

% 准备平坦窗函数g[n]
M = 400; % 截断长度M<N
rec_win = zeros(1, N);
rec_win(1:M) = sinc(((0:M - 1) - M / 2) / B) / B;
gauss_win = zeros(1, N);
std_dev = B * log2(N); % 高斯窗的标准差
gauss_win(1:M) = exp(- ((0:M - 1) - M / 2) .^ 2 / (2 * std_dev ^ 2));
g_n = rec_win .* gauss_win;
g_n = g_n ./ max(abs(g_n));
G_k = fft(g_n);

X_r = zeros(L, N);
X_est = zeros(1, N);

% SFT start
for loop_cnt = 1:L
    % 生成随机参数sigma,sigma_inv,tau
    % sigma为奇数，与N互素。sigma_inv为sigma的数论倒数，即sigma*sigma_inv mod N=1
    sigma = 2 * randi([0, N / 2 - 1]) + 1;
    [~, U] = gcd(sigma, N);
    sigma_inv = mod(U, N);
    tau = randi([1, N]);

    % 频谱随机重排
    p_n = x_n(mod(sigma * (0:N - 1) + tau, N) + 1); % 缩放平移
    y_n = p_n .* g_n; % 与窗函数时域相乘

    % 降采样FFT
    z_n = sum(reshape(y_n, B, []), 2);
    z_n = transpose(z_n);
    Z_k = fft(z_n, B);

    % 按幅度排序取出最大的d*K个
    [~, J] = sort(abs(Z_k), 'descend');
    J = J(1:d * K);

    % hash_sigma:[1,N]-->[1,B]
    hash_sigma = mod(round(mod(sigma * (0:N - 1), N) * B / N), B) + 1;
    % offset_sigma:[1,N]-->[1,N/2B],[N-N/2B-1,N]
    offset_sigma = mod(sigma * (0:N - 1) - round(sigma * (0:N - 1) * B / N) * N / B, N) + 1;

    % J的原像坐标集合I_r
    I_r = find(ismember(hash_sigma, J));
    % 估计幅度
    X_r(loop_cnt, I_r) = Z_k(hash_sigma(I_r)) .* exp(1j * 2 * pi * tau * (I_r - 1) / N) ./ G_k(offset_sigma(I_r));

end

nonzero_freq = find(sum(X_r ~= 0) > L / 2);

for freq = nonzero_freq
    re = median(real(X_r(:, freq)));
    im = median(imag(X_r(:, freq)));
    % num = re + 1j * im;
    % X_est(freq) = abs(num) * exp(1j * (angle(num) + 0.296108836078530));
    X_est(freq) = re + 1j * im;
end

% 绘制幅度谱真值
figure;
subplot(2, 1, 1);
plot((-N / 2:N / 2 - 1), abs(fftshift(S_k)));
title('频域幅度谱真值X[k]');
xlabel('频率/Hz');
ylabel('幅度');
subplot(2, 1, 2);
plot((-N / 2:N / 2 - 1), abs(fftshift(X_est)));
title('SFT 变换得到的X[k]');
xlabel('频率/Hz');
ylabel('幅度');
saveas(gcf, 'image/exp1_spectrum.png');
