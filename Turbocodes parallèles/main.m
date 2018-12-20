clear
clc
close all;




%% Parametres
% -------------------------------------------------------------------------
pqt_par_trame = 100; % Nombre de paquets par trame
bit_par_pqt   = 330;% Nombre de bit par paquet

%% Construction encodeur Trellis

constraint_length=3; %longueur de contrainte du code 1
code=[7 5]; % G1 et G2 du code 1
memoire=constraint_length-1;

K = pqt_par_trame*bit_par_pqt; % Nombre de bits de message par trame

trellis=poly2trellis(constraint_length, code,7); 

encoder =comm.ConvolutionalEncoder(...
    'TrellisStructure', trellis,...
    'TerminationMethod','Truncated');

R = trellis.numInputSymbols/trellis.numOutputSymbols; % Rendement de la communication
N = K/R; % Nombre de bits cod�s par trame (cod�e)
dmin=distspec(trellis); % distance minimale

M = 2; % Modulation BPSK <=> 2 symboles
phi0 = 0; % Offset de phase our la BPSK

EbN0dB_min  = -2; % Minimum de EbN0
EbN0dB_max  = 10; % Maximum de EbN0
EbN0dB_step = 1;% Pas de EbN0

nbr_erreur  = 100;  % Nombre d'erreurs � observer avant de calculer un BER
nbr_bit_max = 100e6;% Nombre de bits max � simuler 
ber_min     = 1e-6; % BER min

EbN0dB = EbN0dB_min:EbN0dB_step:EbN0dB_max;     % Points de EbN0 en dB � simuler
EbN0   = 10.^(EbN0dB/10);% Points de EbN0 � simuler
EsN0   = R*log2(M)*EbN0; % Points de EsN0
EsN0dB = 10*log10(EsN0); % Points de EsN0 en dB � simuler

%Matrice de poin�onnage 
P=[1 1 ; 1 0 ; 0 0 ; 0 1];


% -------------------------------------------------------------------------


%% Construction du modulateur
mod_psk = comm.PSKModulator(...
    'ModulationOrder', M, ... % BPSK
    'PhaseOffset'    , phi0, ...
    'SymbolMapping'  , 'Gray',...
    'BitInput'       , true);

%% Construction du demodulateur
demod_psk = comm.PSKDemodulator(...
    'ModulationOrder', M, ...
    'PhaseOffset'    , phi0, ...
    'SymbolMapping'  , 'Gray',...
    'BitOutput'      , true,...
    'DecisionMethod' , 'Log-likelihood ratio');

%% Construction du canal AWGN
awgn_channel = comm.AWGNChannel(...
    'NoiseMethod', 'Signal to noise ratio (Es/No)',...
    'EsNo',EsN0dB(1),...
    'SignalPower',1);


%% Construction d�codeur Viterbi

viterbi = comm.ViterbiDecoder(...
    'TrellisStructure', poly2trellis(constraint_length, code),...
    'TracebackDepth', constraint_length*5,...
    'TerminationMethod','Truncated', ...
    'InputFormat', 'Unquantized');

%% Construction de l'objet �valuant le TEB
stat_erreur = comm.ErrorRate(); % Calcul du nombre d'erreur et du BER


%% Construction de l'entrelaceur de type BlockInterleaver 

entrelaceur = comm.MatrixInterleaver(330,100);

desentrelaceur = comm.MatrixDeinterleaver(330,100);

%% Construction des d�codeurs 
hAPPDec1=comm.APPDecoder(...
    'TrellisStructure',trellis,...
    'TerminationMethod', 'Truncated',...
    'Algorithm','True APP',...
    'CodedBitLLROutputPort', false);

hAPPDec2=comm.APPDecoder(...
    'TrellisStructure',trellis,...
    'TerminationMethod', 'Truncated',...
    'Algorithm','True APP',...
    'CodedBitLLROutputPort', false);
    
    
%% Initialisation des vecteurs de r�sultats
ber = zeros(1,length(EbN0dB));
Pb = qfunc(sqrt(2*EbN0));

%% Pr�paration de l'affichage
figure(1)
semilogy(EbN0dB,Pb)
hold all
h_ber = semilogy(EbN0dB,ber,'XDataSource','EbN0dB', 'YDataSource','ber');
ylim([1e-6 1])
grid on
xlabel('$\frac{E_b}{N_0}$ en dB','Interpreter', 'latex', 'FontSize',14)
ylabel('TEB','Interpreter', 'latex', 'FontSize',14)

%% Pr�paration de l'affichage en console
msg_format = '|   %7.2f  |   %9d   |  %9d | %2.2e |  %8.2f kO/s |   %8.2f kO/s |   %8.2f s |\n';

fprintf(      '|------------|---------------|------------|----------|----------------|-----------------|--------------|\n')
msg_header =  '|  Eb/N0 dB  |    Bit nbr    |  Bit err   |   TEB    |    Debit Tx    |     Debit Rx    | Tps restant  |\n';
fprintf(msg_header);
fprintf(      '|------------|---------------|------------|----------|----------------|-----------------|--------------|\n')


%% Simulation
for i_snr = 1:length(EbN0dB)
    reverseStr = ''; % Pour affichage en console
    awgn_channel.EsNo = EsN0dB(i_snr);% Mise a jour du EbN0 pour le canal
    
    stat_erreur.reset; % reset du compteur d'erreur
    err_stat    = [0 0 0]; % vecteur r�sultat de stat_erreur
    
    demod_psk.Variance = awgn_channel.Variance;
    
    n_frame = 0;
    T_rx = 0;
    T_tx = 0;
    general_tic = tic;
    while (err_stat(2) < nbr_erreur && err_stat(3) < nbr_bit_max)
        n_frame = n_frame + 1;
        
        %% Emetteur
        tx_tic = tic;                 % Mesure du d�bit d'encodage
        un    = randi([0,1],K,1);    % G�n�ration du message al�atoire
        un_prime = step(entrelaceur,un);
        pn = step(encoder,un) ; % Encodage G1(z)
        qn = step(encoder,un_prime); %Encodage G2(z)
        
        %Poinconnage 
        M = [ un  pn(2:2:end)  un_prime  qn(2:2:end)]';
        [ligne_M col_M] = size(M);
        [ligne_P col_P] = size(P);
        P_rep = repmat(P,[1 col_M/col_P]);
        code = M(P_rep==1);
        
        x      = step(mod_psk,  code); % Modulation QPSK
        T_tx   = T_tx+toc(tx_tic);    % Mesure du d�bit d'encodage
        
        
        %% Canal
        y1= step(awgn_channel,x); % Ajout d'un bruit gaussien
        
        %% Recepteur
        rx_tic = tic;                  % Mesure du d�bit de d�codage
        y     = step(demod_psk,  y1); % Modulation QPSK
        M_r = zeros(size(M));
        M_r(P_rep==1) = -y;
        
        Lcu = M_r(1,:);
        Lcp = M_r(2,:);
        Lcup = M_r(3,:);
        Lcq = M_r(4,:);
        
        Leup_2= zeros(33000, 1); % Entr�e d�codeur 1 qui vaut 0 au d�but 
        
        for I=1:3
        %  ==== 1er d�codeur ====
        Lau_1=step(desentrelaceur,Leup_2)';
        conct_Lcp_Lcu=reshape([Lcu; Lcp], [], 1)'; % On met une composante d'un vecteur, puis une de l'autre, etc...
        Leu_1=step(hAPPDec1, Lau_1', conct_Lcp_Lcu')'; % Sortie du premier d�codeur
        
        
        % === 2eme d�codeur ===
        % Entr�e
        Lcup_2= step(entrelaceur,Lcu')';
        conct_Lcup_Lcq=reshape([Lcup_2; Lcq], [], 1)';
        Laup_2=step(entrelaceur,Leu_1')';
        Leup_2=step(hAPPDec2, Laup_2', conct_Lcup_Lcq'); % Sortie d�codeur 2
        
        
        % Sortie apr�s d�codage 
        Lau_1=step(desentrelaceur,Leup_2);
        end 
        
        L1= Lau_1'+Leu_1+Lcu;
       
        T_rx    = T_rx + toc(rx_tic);  % Mesure du d�bit de d�codage
       
         % Decision 
        rec_msg=double(-L1<0)';
        msg=un;
        err_stat   = step(stat_erreur, msg, rec_msg(1:length(msg))); % Comptage des erreurs binaires
        
        
       
        
        %% Affichage du r�sultat
        if mod(n_frame,100) == 1
            msg = sprintf(msg_format,...
                EbN0dB(i_snr),         ... % EbN0 en dB
                err_stat(3),           ... % Nombre de bits envoy�s
                err_stat(2),           ... % Nombre d'erreurs observ�es
                err_stat(1),           ... % BER
                err_stat(3)/8/T_tx/1e3,... % D�bit d'encodage
                err_stat(3)/8/T_rx/1e3,... % D�bit de d�codage
                toc(general_tic)*(nbr_erreur - min(err_stat(2),nbr_erreur))/nbr_erreur); % Temps restant
            fprintf(reverseStr);
            msg_sz =  fprintf(msg);
            reverseStr = repmat(sprintf('\b'), 1, msg_sz);
        end
        
    end
    
    msg = sprintf(msg_format,EbN0dB(i_snr), err_stat(3), err_stat(2), err_stat(1), err_stat(3)/8/T_tx/1e3, err_stat(3)/8/T_rx/1e3, toc(general_tic)*(100 - min(err_stat(2),100))/100);
    fprintf(reverseStr);
    msg_sz =  fprintf(msg);
    reverseStr = repmat(sprintf('\b'), 1, msg_sz);
    
    ber(i_snr) = err_stat(1);
    refreshdata(h_ber);
    drawnow limitrate
    
    if err_stat(1) < ber_min
        break
    end
    
end
fprintf('|------------|---------------|------------|----------|----------------|-----------------|--------------|\n')

%% Affichage
figure(1)
semilogy(EbN0dB,ber);
hold all
xlim([-4 10])
ylim([1e-6 1])
grid on
xlabel('$\frac{E_b}{N_0}$ en dB','Interpreter', 'latex', 'FontSize',14)
ylabel('TEB','Interpreter', 'latex', 'FontSize',14)

save('NC.mat','EbN0dB','ber','Pb')
