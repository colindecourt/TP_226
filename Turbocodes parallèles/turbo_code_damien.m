clear all
close all
clc
 
nb_interation = 0;
%% Parametres
% -------------------------------------------------------------------------
R = 1/2; % Rendement de la communication
 
pqt_par_trame = 100; % Nombre de paquets par trame
bit_par_pqt   = 330;% Nombre de bit par paquet
K = pqt_par_trame*bit_par_pqt; % Nombre de bits de message par trame
N = K/R; % Nombre de bits codés par trame (codée)

M = 2; % Modulation BPSK <=> 2 symboles
phi0 = 0; % Offset de phase our la BPSK
 
EbN0dB_min  = -2; % Minimum de EbN0
EbN0dB_max  = 10; % Maximum de EbN0
EbN0dB_step = 1;% Pas de EbN0
 
nbr_erreur  = 100;  % Nombre d'erreurs à observer avant de calculer un BER
nbr_bit_max = 100e6;% Nombre de bits max à simuler 
ber_min     = 3e-5; % BER min
 
EbN0dB = EbN0dB_min:EbN0dB_step:EbN0dB_max;     % Points de EbN0 en dB à simuler
EbN0   = 10.^(EbN0dB/10);% Points de EbN0 à simuler
EsN0   = R*log2(M)*EbN0; % Points de EsN0
EsN0dB = 10*log10(EsN0); % Points de EsN0 en dB à simuler
 
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
 
%% Construction de l'objet évaluant le TEB
stat_erreur = comm.ErrorRate(); % Calcul du nombre d'erreur et du BER
 
%% Initialisation des vecteurs de résultats
ber = zeros(1,length(EbN0dB));
Pe = qfunc(sqrt(2*EbN0));
 
%% Préparation de l'affichage
figure(1)
h_ber = semilogy(EbN0dB,ber,'XDataSource','EbN0dB', 'YDataSource','ber');
hold all
ylim([1e-6 1])
grid on
xlabel('$\frac{E_b}{N_0}$ en dB','Interpreter', 'latex', 'FontSize',14)
ylabel('TEB','Interpreter', 'latex', 'FontSize',14)
 
%% Préparation de l'affichage en console
msg_format = '|   %7.2f  |   %9d   |  %9d | %2.2e |  %8.2f kO/s |   %8.2f kO/s |   %8.2f s |\n';
 
fprintf(      '|------------|---------------|------------|----------|----------------|-----------------|--------------|\n')
msg_header =  '|  Eb/N0 dB  |    Bit nbr    |  Bit err   |   TEB    |    Debit Tx    |     Debit Rx    | Tps restant  |\n';
fprintf(msg_header);
fprintf(      '|------------|---------------|------------|----------|----------------|-----------------|--------------|\n')
 
%% Trellis 

trellis_7_5 = poly2trellis(3,[7 5],7); %(7,5)
 
%% matrice de poinconnage

mat_poin = [1 1;1 0;0 0;0 1];
matrice_poinconnage = [];
for i=0:(K-1)/2
    matrice_poinconnage = [matrice_poinconnage mat_poin ];
end

%% APPDecoder

hAPPDec = comm.APPDecoder('TrellisStructure',trellis_7_5,'TerminationMethod','Truncated' ,'Algorithm','True APP','CodedBitLLROutputPort',false);

%% entrelaceur

permVec = randperm(K)';

interLeaver = comm.BlockInterleaver(permVec);
deinterLeaver = comm.BlockDeinterleaver(permVec);

%% encodeur

hConEnc = comm.ConvolutionalEncoder(trellis_7_5,'TerminationMethod','Truncated');

%% Simulation    
 
    for i_snr = 1:length(EbN0dB)
        reverseStr = ''; % Pour affichage en console
        awgn_channel.EsNo = EsN0dB(i_snr);% Mise a jour du EbN0 pour le canal
 
        stat_erreur.reset; % reset du compteur d'erreur
        err_stat    = [0 0 0]; % vecteur résultat de stat_erreur
 
        demod_psk.Variance = awgn_channel.Variance;
 
        n_frame = 0;
        T_rx = 0;
        T_tx = 0;
        general_tic = tic;
        while (err_stat(2) < nbr_erreur && err_stat(3) < nbr_bit_max)
            n_frame = n_frame + 1;
 
            %% Emetteur
            tx_tic = tic;                 % Mesure du débit d'encodage
            msg   = randi([0,1],K,1);    % Génération du message aléatoire
            
            %% RSC1
            msg_encode_1 = step(hConEnc,msg); % Encodage
            pn = msg_encode_1(2:2:end);

            %% RSC2
            msg_entrelace = step(interLeaver,msg); % Entrelaceur
            msg_encode_2 = step(hConEnc,msg_entrelace); % Encodage
            qn = msg_encode_2(2:2:end);

            %% Poinconnage
            
            matrice_avant_poinconnage = [msg';pn';msg_entrelace';qn'];
            Cn = matrice_avant_poinconnage(matrice_poinconnage == 1);
            x      = step(mod_psk,  Cn); % Modulation QPSK

            T_tx   = T_tx+toc(tx_tic);    % Mesure du débit d'encodage
 
            %% Canal
            y     = step(awgn_channel,x); % Ajout d'un bruit gaussien
            
            %% Recepteur
            rx_tic = tic;                  % Mesure du débit de décodage
            Lc = step(demod_psk,y);   % Démodulation (retourne des LLRs)
            
            matrice_depoinconne = zeros(4,K);
            matrice_depoinconne(matrice_poinconnage == 1)=  Lc ;
            
            un = matrice_depoinconne(1,:);
            pn = matrice_depoinconne(2,:);
            %un_prime = matrice_depoinconne(3,:);
            qn = matrice_depoinconne(4,:);
            
            La_desentrelace = zeros(1,33000)'; % Leup_2
            entree_1 = zeros(1,66000);
            entree_1(1:2:end) = un;
            entree_1(2:2:end) = pn; %conct_Lcp_Lcu
            
            entree_2 = zeros(1,66000);
            un_prime = step(interLeaver,un'); % Entrelaceur
            entree_2(1:2:end) = un_prime';
            entree_2(2:2:end) = qn; % conct_Lcup_Lcq
            
           
            
            for i = 0:nb_interation

                 %% APP decoder 1
                Le = step(hAPPDec,La_desentrelace,-entree_1');

                %% APP decoder 2
                Le_entrelace = step(interLeaver,Le); % Entrelaceur

                La = step(hAPPDec,Le_entrelace,-entree_2');
                La_desentrelace = step(deinterLeaver,La); % Entrelaceur

            end

            
            Lu = La_desentrelace' + Le' + un;
            
            rec_msg_2 = double(-Lu(1:K) < 0); % Décision
            T_rx    = T_rx + toc(rx_tic);  % Mesure du débit de décodage
            err_stat   = step(stat_erreur, msg, rec_msg_2(1:K)'); % Comptage des erreurs binaires
 
            %% Affichage du résultat
            if mod(n_frame,100) == 1
                msg = sprintf(msg_format,...
                    EbN0dB(i_snr),         ... % EbN0 en dB
                    err_stat(3),           ... % Nombre de bits envoyés
                    err_stat(2),           ... % Nombre d'erreurs observées
                    err_stat(1),           ... % BER
                    err_stat(3)/8/T_tx/1e3,... % Débit d'encodage
                    err_stat(3)/8/T_rx/1e3,... % Débit de décodage
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
 
%%
figure(1)
semilogy(EbN0dB,ber);
hold all
xlim([0 10])
ylim([1e-6 1])
grid on
xlabel('$\frac{E_b}{N_0}$ en dB','Interpreter', 'latex', 'FontSize',14)
ylabel('TEB','Interpreter', 'latex', 'FontSize',14)
file_name = sprintf('turbo_I_%d.mat',nb_interation);
save(file_name,'EbN0dB','ber')