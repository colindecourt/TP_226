close all
figure(1)
NC1= load('NC_intro.mat');
NC2= load('NC_sansentrelaceur.mat');
NC4= load('NC4_fermé.mat');
NC = load('NC.mat');


semilogy(NC.EbN0dB,NC.Pb);
hold on
semilogy(NC1.EbN0dB,NC1.ber);
semilogy(NC2.EbN0dB,NC2.ber);
semilogy(NC4.EbN0dB,NC4.ber);



xlim([-2 10])
ylim([1e-6 1])
grid on
xlabel('$\frac{E_b}{N_0}$ en dB','Interpreter', 'latex', 'FontSize',14)
ylabel('TEB','Interpreter', 'latex', 'FontSize',14)
legend({'Peb non codee','Code concatene avec entrelaceur et codeur RS','Code concatene sans entrelaceur et codeur RS','Code (133,171)'}, 'Interpreter', 'latex', 'FontSize',11);
title('TEB en fonction de Eb/N0 pour chacun des codes');