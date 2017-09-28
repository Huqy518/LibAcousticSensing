%==========================================================================
% 2017/01/26: Set paths of local helpers and lib
%==========================================================================
libPath = '../../../LibAcousticSensing/Matlab/'
oriPath = cd(libPath)

LibSetup; % setup paths for the core LibAcousticSensing

cd(oriPath);
addpath('LocalHelpers');
clear oriPath

% check if the java class is correctly included
LibLoad;
which JavaSensingServer