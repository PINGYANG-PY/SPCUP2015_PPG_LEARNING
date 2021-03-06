extract_features;
save_groundtruths;
load('features.mat');
load('ground_truths.mat');
indexes_all = 1:13;

% parameters
c = 2048;
gamma = 0.00625;
window_dist = 'uniform';  % 'gaussian'
window_size = 15;
window_gau_sdtype = 'd2';
use_lastpredict = 1;
lastpredict_num = 20;
past_acc_end = 0;
acc_num = 0;
peak_win_num = 12;

% window_str to be shown in the name of the exp
if strcmp(window_dist, 'uniform') == 1
    window_str = window_dist;
elseif strcmp(window_dist, 'gaussian') == 1
    window_str = sprintf('gaussian_%s', window_gau_sdtype);
end

% for storing results
% corr: correlation coefficient ^ 2
% aae: average absolute error
corr_sum_predict = 0;
aae_sum_predict = 0;
corr_sum_track = 0;
aae_sum_track = 0;
corr_sum_smooth = 0;
aae_sum_smooth = 0;

% directories
exp_root_dir = 'exp';
date = datestr(now, 'yyyymmdd_HHMMSS');

if (ispc); sep = '\\';
else       sep = '/';  end


%exp name: <c>_<gamma>_t<thres>_<delta>_s<winsize>_<window_str>_<date>
exp_name = sprintf('lp%d_%dNM_ppgonly__acc_12345_%d_%d_initpeak%d__%s', use_lastpredict, lastpredict_num, past_acc_end, acc_num, peak_win_num, date);
%exp_name = sprintf('%f_%f__%s', c, gamma, date);
exp_dir = sprintf(['%s' sep '%s'], exp_root_dir, exp_name);
tmp_dir = sprintf(['%s' sep 'tmp'], exp_dir);
mkdir(exp_dir);
mkdir(tmp_dir);

% result file
resf = fopen(sprintf(['%s' sep 'results.txt'], exp_dir), 'w+');

fprintf(1, 'Experiment starting: %s\n\n', exp_name);

tic;
for i = 1:13

    fprintf(1, '\nTest %d\n', i);
    train_idxes = indexes_all( ~ismember( indexes_all, i ) );
    training_file = sprintf(['%s' sep 'my_train_no_%d'], tmp_dir, i);
    predict_file = sprintf(['%s' sep 'my_predict_%d'], tmp_dir, i);
    output_file = sprintf(['%s' sep 'my_out_%d'], exp_dir, i);
    fig_file = sprintf(['%s' sep 'plot_%d'], exp_dir, i);

    %train
    model = ...
            my_svm_train(training_file, c, gamma, train_idxes, lastpredict_num, past_acc_end, acc_num);

    %predict
    [mse_predict, corr_predict, aae_predict, tgt_label, out_label_predict] = ...
            my_svm_predict(model, predict_file, output_file, i, use_lastpredict, lastpredict_num, past_acc_end, acc_num, peak_win_num);

    %temporal track
    [mse_track, corr_track, aae_track, out_label_track] = ...
            my_mod_track(tgt_label, out_label_predict);

    %window_smooth
    [mse_smooth, corr_smooth, aae_smooth, out_label_smooth] = ...
            my_mod_window_smooth(tgt_label, out_label_track, window_dist, window_size, window_gau_sdtype);



    % plot
    my_plot_func(fig_file, tgt_label, out_label_predict, aae_predict);

    % save results to file and screen
    for f = [1, resf]
        fprintf(f, 'predict %d:mse = %f , corr = %f , avg_abs_err = %f\n', i, mse_predict, corr_predict, aae_predict);
        fprintf(f, 'tracked %d:mse = %f , corr = %f , avg_abs_err = %f\n', i, mse_track, corr_track, aae_track);
        fprintf(f, 'smooth  %d:mse = %f , corr = %f , avg_abs_err = %f\n', i, mse_smooth, corr_smooth, aae_smooth);      
    end

    fprintf(1, 'result : mse %f , corr %f , avg_abs_err = %f\n', mse_smooth, corr_smooth, aae_smooth);

    corr_sum_predict = corr_sum_predict + corr_predict;
    aae_sum_predict = aae_sum_predict + aae_predict;
    corr_sum_track = corr_sum_track + corr_track;
    aae_sum_track = aae_sum_track + aae_track;
    corr_sum_smooth = corr_sum_smooth + corr_smooth;
    aae_sum_smooth = aae_sum_smooth + aae_smooth;
end

count = size(indexes_all, 2);
for f = [1, resf]
    fprintf(f, 'Average corr: predict = %f\n', corr_sum_predict / count);
    fprintf(f, 'Average corr: track   = %f\n', corr_sum_track / count);
    fprintf(f, 'Average corr: smooth  = %f\n', corr_sum_smooth / count);

    fprintf(f, 'Average aae(BPM): predict = %f\n', aae_sum_predict / count);
    fprintf(f, 'Average aae(BPM): track   = %f\n', aae_sum_track / count);
    fprintf(f, 'Average aae(BPM): smooth  = %f\n', aae_sum_smooth / count);
end

fclose(resf);
fclose all;
close all;

fprintf(1, sprintf('Exp: %s succeeded!\n', exp_name));
toc;

%rmdir(tmp_dir, 's');
exp_dir_succ = sprintf('%s__succ', exp_dir);
copyfile(exp_dir, exp_dir_succ);
%rmdir(exp_dir, 's');
