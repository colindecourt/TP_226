close all
figure(1)
NC0= load('0_iterations.mat');
NC3= load('3_iterations.mat');
NC8= load('8_iterations.mat');
NC = load('NC.mat');




semilogy(NC.EbN0dB,NC.Pb);
 hold on
 semilogy(NC0.EbN0dB,NC0.ber);
 semilogy(NC3.EbN0dB,NC3.ber);
 semilogy(NC8.EbN0dB,NC8.ber);
% semilogy(NC4.EbN0dB,NC4.ber);
% 


xlim([-2 10])
ylim([1e-6 1])
grid on
xlabel('$\frac{E_b}{N_0}$ en dB','Interpreter', 'latex', 'FontSize',14)
ylabel('TEB','Interpreter', 'latex', 'FontSize',14)
legend({'Peb non codee','Turbocode I=0','Turbocode I=3','Turbocode I=8'}, 'Interpreter', 'latex', 'FontSize',11);
title('TEB en fonction de Eb/N0 pour chacun des codes');