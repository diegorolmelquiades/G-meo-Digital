%% dados_cenarios.m  (revisado AP1)
% Sombra Digital - Ficha B4 (grupo gerador diesel, sistema isolado)
% Usina escalada a partir de Apui: 40 x UTE 550 + 10 transformadores.
% Rodar antes da simulacao ou chamar no InitFcn: run('dados_cenarios.m');
% Linhas marcadas com [REV] foram acrescentadas/alteradas na revisao.
 
%% 0) CENARIO (editar SOMENTE esta secao)
%   'C1' caso base (12 MW constantes, sem festividade)
%   'C2' curva de 24 h do CSV (perfil variavel; valores horarios por Load Flow, Secao 3.5)
%   'C3' festividade em regime (14 MW, banco ligado desde t = 0)
%   'C5' degrau da festividade: festa e banco fecham em t = t_evento (12 -> 14 MW)
%   'C6' perda de um bloco: maquina de 9 blocos + degrau de 1,435 MW em t = t_evento (equivale a perder 1 bloco)
cenario  = 'CX';
t_evento = 1;                           % s, instante do evento (C5 e C6)
 
% Chaves derivadas do cenario (nao editar)
fixar_base_lf = true;   evento_C5 = false;   evento_C6 = false;
N_sim = 10;             fest_estado_ini = 0; Pm0_est = 0.621859;        % Pm0_est: estimativa (usar o valor da mensagem do Load Flow)
switch cenario
    case 'C1'
    case 'C2', fixar_base_lf = false;
    case 'C3', fest_estado_ini = 1;  Pm0_est = 0.730088;
    case 'C5', evento_C5 = true;
    case 'C6', evento_C6 = true;  N_sim = 9;  Pm0_est = 0.691459;      % festa aberta; degrau resistivo em t_evento (Secao 14)
    otherwise, error('cenario invalido: use C1, C2, C3, C5 ou C6');
end
fprintf('=== Cenario %s | N_sim = %d | festa fechada em t0: %d ===\n', cenario, N_sim, fest_estado_ini);
 
%% 1) Solver e escala de tempo
Ts = 5e-5;                    % s. So e usado se o powergui voltar ao modo Discrete.
% seg_por_hora so e usado pelo perfil lido no From Workspace e pelos
% tempos do Breaker. Os valores horarios da AP2 sao obtidos por Load Flow
% hora a hora (Secao 3.5); os eventos C5 e C6 sao simulados por 20 s.
seg_por_hora = 1;             % 1 s simulado = 1 h (apenas para o perfil)
 
%% 2) Curva de carga 24 h (arquivo do professor)
T            = readtable('curva_carga_24h.csv');   % na pasta do modelo
horas        = double(T.hora(:));                  % 0..23 (em horas)
fator        = double(T.fator_carga(:));           % media = 0,804
temp_amb     = double(T.temp_ambiente_C(:));       % [REV] C, usada no derating
perfil_carga = [horas*seg_por_hora fator];         % Nx2 (tempo simulado, fator) -> From Workspace
assert(size(perfil_carga,1)==24 && size(perfil_carga,2)==2 && ...
       ~any(isnan(perfil_carga(:))), 'perfil_carga invalido: confira o CSV');
% Cenarios C1, C3, C5 e C6: carga constante no caso base (toda a curva em 1,0); C2 usa o perfil do CSV.
if fixar_base_lf, perfil_carga(:,2) = 1.0; end
 
%% 3) Geradores UTE 550 (regime Prime, ficha do fabricante [21])
S_unit   = 503e3;             % VA por gerador (Prime, ficha)
P_unit   = 0.8*S_unit;        % W, ~402,4 kW (FP nominal 0,8)
% [REV] Premissa: potencia aparente Prime da ficha x FP de placa; o consumo
% do ventilador eletrico nao e descontado (a ficha nao o informa).
N_ativos = 40;                % 10 blocos x 4 geradores  [ASSUNCAO de projeto]
Sn_usina = N_ativos*S_unit;   % 20,12 MVA
Pn_usina = N_ativos*P_unit;   % 16,10 MW
 
%% 4) Maquina sincrona equivalente (Synchronous Machine pu Standard)
Sn_maq = Sn_usina;            % VA (20,12 MVA com 10 blocos)
Vn_maq = 13.8e3;              % V. Maquina equivalente referida ao lado de 13,8 kV
% Nota: a usina real gera em 0,48 kV e eleva para 13,8 kV (trafos Dyn1).
% No modelo o gerador e referido ao lado de 13,8 kV (relacao 13,8/13,8 kV),
% mantendo a impedancia Z_eq em pu na base de 20,5 MVA.
fn     = 60;                  % Hz
polos  = 4;                   % 1800 rpm @ 60 Hz
 
% Parametros em pu na BASE PROPRIA da maquina (Sn_maq): valores de referencia
% da literatura (Dong et al. [5], Tab. 1). Nao sao do alternador WEG real. [ASSUNCAO]
Xd = 1.346; Xq = 0.940; Xd_t = 0.446; Xd_st = 0.330; Xq_st = 0.370;   % pu
Xl = 0.243; Rs = 0.006;                                               % pu
Td0_t = 1.660; Td0_st = 0.118; Tq0_st = 0.035;                        % s (circuito aberto)
% Vetores para os campos do bloco (d axis e q axis: Open-circuit):
X_maq  = [Xd Xd_t Xd_st Xq Xq_st Xl];   % Reactances [Xd Xd' Xd'' Xq Xq'' Xl]
Td_maq = [Td0_t Td0_st];                % d axis time constants
Tq_maq = Tq0_st;                        % q axis time constant
 
% Inercia
w_mec  = 2*pi*fn/(polos/2);                 % rad/s (1800 rpm)
H_alt  = 0.5*5.78*w_mec^2/S_unit;           % ~0,204 s (J do alternador, ficha [21]; sem motor/volante)
H_maq  = 1.2;                               % s, base propria (Dong et al. [5]); ajustar se obtiver o J do conjunto
if exist('H_sens','var'), H_maq = H_sens; end   % sensibilidade de H: definir H_sens no workspace (rodar_sensibilidade_H.m)
Vref_exc = 1.00;                            % pu, referencia do Excitation System
 
% Conversao para a base de 100 MVA (Tabela 3): x_100 = x_propria*100e6/Sn_maq
S_base = 100e6;  k_base = S_base/Sn_maq;                                % 4,970
Xd_100 = Xd*k_base;  Xq_100 = Xq*k_base;  Xd_t_100 = Xd_t*k_base;       % 6,690; 4,672; 2,217
Xd_st_100 = Xd_st*k_base;  Xq_st_100 = Xq_st*k_base;                    % 1,640; 1,839
Xl_100 = Xl*k_base;  Rs_100 = Rs*k_base;                                % 1,208; 0,0298
H_100  = H_maq*Sn_maq/S_base;                                           % 0,241 s
 
%% 5) Transformadores (Apui real + acrescentados)
S_tr = [2000 2000 2000 2000 2500  2000 2000 2000 2000 2000]*1e3;   % VA
Z_tr = [7.10 7.03 6.86 6.90 6.90  6.97 6.97 6.97 6.97 6.97]/100;   % pu, base propria
% Unidades 1-5 = placa real; 6-10 = acrescentadas, Z = media das 2000 kVA [ASSUNCAO]
S_trafo = sum(S_tr);                        % 20,5 MVA
Z_eq    = S_trafo/sum(S_tr./Z_tr);          % 0,0696 pu na base S_trafo (paralelo)
Z_eq_100MVA = Z_eq*100e6/S_trafo;           % 0,340 pu na base 100 MVA
XR   = 10;                                  % relacao X/R
R_eq = Z_eq/sqrt(1+XR^2);
X_eq = XR*R_eq;
R1 = R_eq/2;  R2 = R_eq/2;                  % pu (bloco Three-Phase Transformer)
L1 = X_eq/2;  L2 = X_eq/2;                  % pu
V_AT = 13.8e3;  V_BT = 13.8e3;              % V (modelo). Valor real do secundario: 480 V
Rm = 500;  Lm = 500;                        % pu, ramo de magnetizacao [ASSUNCAO]
P_ferro = S_trafo/Rm;                       % W, perda no ferro dos 10 trafos (~41 kW); o Peo do Simulink a inclui,
                                            % os gabaritos desta secao nao (efeito ~0,3 %)
 
%% 5b) [REV] Linhas LT-1 (B2-B3) e LT-2 (B3-B4), 13,8 kV, sem capacitancia shunt
r_km = 0.27;  x_km = 0.38;                  % ohm/km (Tabela 5)
len_LT1 = 2;  len_LT2 = 3;                  % km
R_LT1 = r_km*len_LT1;                       % 0,54 ohm
L_LT1 = x_km*len_LT1/(2*pi*fn);             % 2,016 mH  (usar no Series RLC Branch)
R_LT2 = r_km*len_LT2;                       % 0,81 ohm
L_LT2 = x_km*len_LT2/(2*pi*fn);             % 3,024 mH
Zbase_100 = (13.8e3)^2/100e6;               % 1,9044 ohm (base 100 MVA, 13,8 kV)
z_LT1_pu = (R_LT1 + 1j*2*pi*fn*L_LT1)/Zbase_100;   % 0,2835 + j0,3991
z_LT2_pu = (R_LT2 + 1j*2*pi*fn*L_LT2)/Zbase_100;   % 0,4253 + j0,5986
 
%% 6) Cargas (barras 2, 3 e 4) - Three-Phase Dynamic Load, porta PQ
FP        = 0.95;                           % Fator adotado
Vn_carga  = 13.8e3;                         % V, barras de carga na AT
P_pico    = 12e6;                           % W, pico da curva base (fator = 1,0)
shares    = [0.5 0.3 0.2];                  % divisao entre cargas 1, 2, 3
P_base    = shares(1)*P_pico;               % 6,0 MW -> Gain P (carga 1)
Q_base    = P_base*tan(acos(FP));           % Gain Q (carga 1)
k2        = shares(2)/shares(1);            % 0,6 -> Gain escalar da carga 2
k3        = shares(3)/shares(1);            % 0,4 -> Gain escalar da carga 3
% [REV] Cargas resistivas de estabilidade numerica (artificio do modelo)
P_estab   = 4*50e3;                         % W (4 x 50 kW: terminal da maquina, B2, B3 e B4; evitam o erro de
                                            % elementos indutivos em serie); nao entram no consumo
 
%% 7) Cenario extraordinario: festividade (barra 4)
P_fest = 2e6;                               % W [ASSUNCAO]
Q_fest = P_fest*tan(acos(FP));              % var
t_fest = [18 22];                           % 18 22 h: Breaker fecha em 18, abre em 22
t_fest_sim = t_fest*seg_por_hora;           % s simulados -> Transition times do Breaker
% Three-Phase Parallel RLC Load na barra 4: [Vn_carga fn], P = P_fest, QL = Q_fest
% [REV] Banco de capacitores em B4, em paralelo com a carga da festividade
% (mesmo breaker): desligado no caso base, ligado apenas na festividade (C3).
Q_cap = 2e6;                                % var (2 Mvar)
t_cap_sim = t_fest_sim;                     % liga e desliga junto com a festividade
% Three-Phase Parallel RLC Load: [Vn_carga fn], P = 0, QC = Q_cap
 
%% 7b) [REV] Governor de velocidade (documentacao dos parametros do modelo)
% Valores do modelo (Tabela 8; limitador de taxa +-0,5 pu/s).
Kp_gov = 2;  Ki_gov = 0.5;  Kd_gov = 0;     % PID sobre o erro de velocidade (pu). Ajustado no C5: (4; 1,5) oscilou com amplitude crescente
lim_PID = 0.3;                              % pu, saturacao da saida do PID
Pref_gov = 0.75;                            % pu, referencia de potencia
rate_lim = 0.5;                             % pu/s (Tabela 8)
Tm_gov = 1.0;                               % s, constante de tempo 1/(s+1)
Pm_sat = [0 1.1];                           % pu, limites (110 % Prime por 1 h a cada 12 h)
% Condicoes iniciais do governor (caso base de 12 MW). Pm0_gov = valor pedido pela mensagem do Load Flow
% ("set the initial condition ... to: X pu"); ~0,62 pu no caso base. ATUALIZAR com o valor da mensagem.
Pm0_gov  = Pm0_est;                         % pu, definido pelo cenario (Secao 0); conferir com a mensagem do Load Flow
PID_int0 = Pm0_gov - Pref_gov;              % pu, saida inicial do PID (-0,128 se Pm0 = 0,622)
% No Simulink: (1) estado inicial do filtro 1/(Tm s+1) = Pm0_gov (bloco State-Space: A=-1/Tm_gov,
% B=1/Tm_gov, C=1, D=0, condicao inicial Pm0_gov); (2) PID: saida em t=0 = PID_int0.
 
%% 7c) [REV] Verificacao da Tabela 3 (base 100 MVA, 10 blocos)
R_eq_100 = R_eq*S_base/S_trafo;  X_eq_100 = X_eq*S_base/S_trafo;        % 0,0338; 0,338
fprintf('--- Tabela 3 (base 100 MVA) ---\n');
fprintf('Xd=%.3f | Xq=%.3f | Xd_t=%.3f | Xd_st=%.3f | Xq_st=%.3f | Xl=%.3f | Rs=%.4f | H=%.3f s\n', ...
        Xd_100, Xq_100, Xd_t_100, Xd_st_100, Xq_st_100, Xl_100, Rs_100, H_100);
fprintf('Zeq=%.3f | Req=%.4f | Xeq=%.3f pu\n', Z_eq_100MVA, R_eq_100, X_eq_100);
fprintf('Carga 1: %.4f + j%.4f | Carga 2: %.4f + j%.4f | Carga 3: %.4f + j%.4f\n', ...
        P_base/S_base, Q_base/S_base, k2*P_base/S_base, k2*Q_base/S_base, ...
        k3*P_base/S_base, k3*Q_base/S_base);
fprintf('Festividade: %.4f + j%.4f | banco: -j%.4f\n', P_fest/S_base, Q_fest/S_base, Q_cap/S_base);
assert(abs(Xd_100-6.690) < 1e-3 && abs(Xq_100-4.672) < 1e-3 && abs(Xd_t_100-2.217) < 1e-3 && ...
       abs(Xd_st_100-1.640) < 1e-3 && abs(Xq_st_100-1.839) < 1e-3 && abs(Xl_100-1.208) < 1e-3 && ...
       abs(Rs_100-0.0298) < 1e-4 && (abs(H_100-0.241) < 1e-3 || exist('H_sens','var')), 'Tabela 3 (maquina) nao confere');
 
%% 8) Limites e alarmes
V_min = 0.95;  V_max = 1.05;                % pu, meta de projeto (mais restritiva)
V_min_prodist = 0.93;                       % [REV] pu, faixa adequada PRODIST (1-69 kV)
carreg_max = 1.0;                           % P_ger/Pn_usina
 
%% 9) Consumo especifico (1-D Lookup Table) - entrada: P_ger/Pn_usina
cons_bp      = [0.10 0.25 0.50 0.75 1.00];
k_cons       = 0.84;    % reescala p/ ~0,237 L/kWh a 80% (ficha [21]: 230-244 L/MWe no COP)
cons_tab     = k_cons*[0.50 0.38 0.30 0.283 0.28];   % L/kWh (forma da curva: literatura)
preco_diesel = 7.50;    % R$/L  (citar fonte na AP2)
% [REV] Validacao parcial contra a ficha (unico ponto declarado: COP = 80 % do Prime)
c80 = interp1(cons_bp, cons_tab, 0.80, 'linear');
assert(c80 >= 0.230 && c80 <= 0.244, 'c(0,8) fora da faixa da ficha (0,230-0,244 L/kWh)');
% Ganhos da cadeia de consumo no Simulink (a partir do sinal Peo, pu da maquina):
k_carreg    = Sn_maq/Pn_usina;   % Gain: Peo -> carregamento da usina (pu), ~1,25
k_kW        = Sn_maq/1e3;        % Gain: Peo -> potencia ativa (kW)
k_estab_pu  = P_estab/Sn_maq;    % [REV] subtrair de Peo (pu) antes da Lookup Table
ganho_tempo = 1/seg_por_hora;    % Gain antes do Integrator (s simulados -> horas)
 
%% 10) Verificacoes da curva de carga
h   = horas;                                % horas do dia (0..23)
P_h = P_pico*fator + P_fest*(h>=t_fest(1) & h<t_fest(2));   % gabaritos usam sempre a curva do CSV (independe do cenario)
fprintf('Pico: %.2f MW | Media: %.2f MW\n', max(P_h)/1e6, mean(P_h)/1e6);
fprintf('Carregamento no pico: %.1f%% (kW) | %.1f%% (kVA)\n', ...
        100*max(P_h)/Pn_usina, 100*max(P_h)/FP/Sn_usina);
fprintf('Carregamento medio: %.1f%% (limite Prime: 70%%)\n', 100*mean(P_h)/Pn_usina);
fprintf('Trafo: %.1f%% no pico | Z_eq = %.4f pu (%.3f pu em 100 MVA)\n', ...
        100*max(P_h)/FP/S_trafo, Z_eq, Z_eq_100MVA);
fprintf('H do alternador (J da ficha): %.3f s | H adotado: %.2f s\n', H_alt, H_maq);
fprintf('Linhas: LT-1 = %.4f%+.4fj pu | LT-2 = %.4f%+.4fj pu\n', ...
        real(z_LT1_pu), imag(z_LT1_pu), real(z_LT2_pu), imag(z_LT2_pu));
if max(P_h) > Pn_usina,        warning('Pico acima da potencia Prime da usina.'); end
if mean(P_h) > 0.70*Pn_usina,  warning('Media diaria acima de 70 % do Prime.');   end
% [REV] N-1 (perda de um bloco de 4 geradores): 14,49 MW
Cap_N1 = Pn_usina - 4*P_unit;               % W
fprintf('Capacidade N-1: %.2f MW | margem sobre as cargas: %.1f%%\n', ...
        Cap_N1/1e6, 100*(Cap_N1-max(P_h))/max(P_h));
 
%% 11) Consumo de diesel e custo diario (calculo de referencia p/ validar o modelo)
% Reproduz, fora do Simulink, o que a Lookup Table + Integrador vao calcular
% dentro do modelo -- serve de "gabarito" para a Camada 4 (Passo 5c).
carreg_h  = P_h/Pn_usina;                                    % carregamento por hora (pu)
cons_h    = interp1(cons_bp, cons_tab, carreg_h, 'linear');  % L/kWh por hora
E_h_kWh   = P_h/1e3;                                         % kWh na hora (duracao = 1 h)
L_h       = cons_h.*E_h_kWh;                                 % L consumidos naquela hora
L_dia     = sum(L_h);                                        % L/dia
custo_dia = L_dia*preco_diesel;                              % R$/dia
cons_medio = L_dia/sum(E_h_kWh);                             % L/kWh medio do dia
fprintf('--- Consumo e custo (gabarito: so cargas) ---\n');
fprintf('Consumo especifico medio do dia: %.3f L/kWh\n', cons_medio);
fprintf('Consumo de diesel: %.0f L/dia\n', L_dia);
fprintf('Custo de combustivel: R$ %.2f/dia (preco: R$ %.2f/L)\n', custo_dia, preco_diesel);
 
%% 11b) [REV] Gabarito com perdas da rede (comparavel ao Peo - P_estab do Simulink)
% Perdas (transformador + LT-1 + LT-2) por hora, em MW, do fluxo de carga
% analitico (B1 = 1,00 pu, banco ligado so na festividade). SUBSTITUIR pelos
% valores do Load Flow do powergui quando a simulacao com linhas estiver rodando.
perdas_h = 1e6*[0.079 0.069 0.062 0.060 0.062 0.074 0.096 0.128 ...
                0.153 0.164 0.172 0.180 0.172 0.164 0.172 0.180 ...
                0.189 0.201 0.377 0.377 0.365 0.320 0.128 0.096]';   % W
P_ger_h   = P_h + perdas_h;                                  % W nos terminais (sem P_estab)
carreg_g  = P_ger_h/Pn_usina;
cons_g    = interp1(cons_bp, cons_tab, carreg_g, 'linear');
L_dia_g   = sum(cons_g.*(P_ger_h/1e3));                      % L/dia
fprintf('--- Consumo e custo (gabarito: cargas + perdas da rede) ---\n');
fprintf('Perdas medias: %.3f MW | energia perdida: %.2f MWh\n', mean(perdas_h)/1e6, sum(perdas_h)/1e6);
fprintf('Consumo de diesel: %.0f L/dia (+%.2f%% sobre o gabarito so de cargas)\n', ...
        L_dia_g, 100*(L_dia_g/L_dia-1));
fprintf('Custo de combustivel: R$ %.2f/dia\n', L_dia_g*preco_diesel);
fprintf('Geracao nos terminais no pico: %.2f MW | margem N-1: %.2f%%\n', ...
        max(P_ger_h)/1e6, 100*(Cap_N1-max(P_ger_h))/max(P_ger_h));
% Derating maximo suportado pela reserva N-1 em cada hora (k minimo)
k_min_N1 = P_ger_h/Cap_N1;
fprintf('k minimo (18 h): %.4f -> derating maximo %.2f%% (T = %.1f C)\n', ...
        k_min_N1(19), 100*(1-k_min_N1(19)), temp_amb(19));
 
%% 12) [REV] Despacho com bloco(s) de reserva (backup em espera)
% Politica: N_base blocos permanecem ligados o dia todo; os N_backup blocos de
% reserva (4 geradores cada) ficam em espera e entram automaticamente quando a
% reserva N-1 "girante" das unidades em linha deixa de cobrir a demanda nos
% terminais:  (N-1)*Cb >= P_ger.  Saem com histerese (fator_desliga).
% Resultado com N_backup = 1: o bloco de reserva fecha as 18 h e abre as 22 h,
% a mesma janela da festividade (t_fest).
N_blocos  = 10;                  % blocos de 4 geradores (40 unidades)
N_backup  = 1;                   % RECOMENDADO: 1. Com 2, a media de 24 h das unidades-base
                                 % passa de 70 % da Prime (limite da ficha [21] / ISO 8528-1)
N_base    = N_blocos - N_backup; % blocos sempre ligados
Cb        = 4*P_unit;            % W por bloco (1,6096 MW)
fator_desliga = 0.90;            % histerese: so desliga se (N-2) blocos cobrem a demanda com 10 % de folga
 
% Perdas da rede com despacho 9+1 (fluxo de carga analitico, Z_eq com N trafos em paralelo,
% B1 = 1,00 pu, banco so na festividade). VALIDO PARA N_backup = 1.
% SUBSTITUIR pelos valores do Load Flow do powergui quando a simulacao estiver rodando.
perdas_h_9m1 = 1e6*[0.082 0.071 0.064 0.062 0.064 0.076 0.099 0.132 ...
                    0.158 0.170 0.178 0.186 0.178 0.170 0.178 0.186 ...
                    0.195 0.208 0.377 0.377 0.365 0.320 0.132 0.099]';   % W
perdas_disp = perdas_h_9m1;
 
% Cronograma de blocos em linha (automacao do despacho)
N_h = zeros(24,1);  N = N_base;
for k = 1:24
    Pg = P_h(k) + perdas_disp(k);                              % W nos terminais (sem P_estab)
    while N < N_blocos && (N-1)*Cb < Pg,                N = N+1; end   % fecha disjuntor do backup
    while N > N_base   && (N-2)*Cb*fator_desliga >= Pg, N = N-1; end   % abre disjuntor do backup
    N_h(k) = N;
end
 
% Janela de operacao do(s) bloco(s) de reserva (analogo a t_fest)
idx_bk = find(N_h > N_base);
if isempty(idx_bk)
    t_bk = [NaN NaN];
else
    t_bk = [h(idx_bk(1)), h(idx_bk(end))+1];                   % h: liga em 18 e desliga em 22
end
t_bk_sim = t_bk*seg_por_hora;                                  % s simulados -> Transition times do Breaker do backup
% (valido para uma unica janela continua; se o cronograma tiver mais de uma, usar o vetor N_h)
 
% Parametros equivalentes por numero de blocos em linha (n = 1..N_blocos)
% Blocos 1..n = trafos 1..n (backup = ultimos trafos: 2000 kVA, 6,97 %)
S_trafo_N = zeros(1,N_blocos);  Z_eq_own_N = zeros(1,N_blocos);  Z_eq100_N = zeros(1,N_blocos);
for n = 1:N_blocos
    S_trafo_N(n)  = sum(S_tr(1:n));                            % VA
    Z_eq_own_N(n) = S_trafo_N(n)/sum(S_tr(1:n)./Z_tr(1:n));    % pu na base S_trafo_N(n)
    Z_eq100_N(n)  = Z_eq_own_N(n)*100e6/S_trafo_N(n);          % pu na base 100 MVA
end
R_eq_N = Z_eq_own_N/sqrt(1+XR^2);   X_eq_N = XR*R_eq_N;         % pu (base propria)
Sn_maq_N = (1:N_blocos)*4*S_unit;                              % VA da maquina equivalente com n blocos
Pn_N     = (1:N_blocos)*Cb;                                    % W
 
% Verificacoes do despacho
P_g_h      = P_h + perdas_disp;                                % W nos terminais
carreg_un  = P_g_h./(N_h*Cb);                                  % pu da Prime das unidades em linha
media_base = mean(P_g_h./(N_h*4))/P_unit;                      % media 24 h por unidade-base (pu da Prime)
folga_N1   = ((N_h-1)*Cb - P_g_h)./P_g_h;                      % reserva N-1 girante
fprintf('--- Despacho: %d blocos base + %d de reserva ---\n', N_base, N_backup);
fprintf('Blocos em linha por hora: %s\n', sprintf('%d ', N_h));
fprintf('Reserva fecha as %g h e abre as %g h\n', t_bk(1), t_bk(2));
fprintf('Folga N-1 minima: %.2f%% | carregamento maximo por unidade: %.1f%% da Prime\n', ...
        100*min(folga_N1), 100*max(carreg_un));
fprintf('Media de 24 h por unidade-base: %.1f%% da Prime (limite 70%%)\n', 100*media_base);
if media_base > 0.70,   warning('Media de 24 h das unidades-base acima de 70 % da Prime.'); end
if min(folga_N1) < 0,   warning('Reserva N-1 girante nao cobre a demanda em alguma hora.'); end
if max(carreg_un) > 1,  warning('Unidade acima da Prime (110 % so por 1 h a cada 12 h).');   end
cons_N  = interp1(cons_bp, cons_tab, carreg_un, 'linear');
assert(~any(isnan(cons_N)), 'carregamento fora da faixa da tabela de consumo (0,10-1,00)');
L_dia_N = sum(cons_N.*(P_g_h/1e3));                            % L/dia (reparto igual entre unidades em linha)
fprintf('Consumo de diesel: %.0f L/dia (%+.1f%% vs 40 unidades ligadas) | R$ %.2f/dia\n', ...
        L_dia_N, 100*(L_dia_N/L_dia_g-1), L_dia_N*preco_diesel);
% Atencao: a economia depende da forma da curva c(eta) (literatura, reescalada pela ficha em 1 ponto).
 
%% 12b) [REV] Modelo de laco horario (Load Flow) -- MODELO, ajustar nomes dos blocos
% Para cada hora k, reparametriza a maquina equivalente e o trafo equivalente para N_h(k) blocos.
% Confirme os nomes dos parametros com:  get_param(bloco,'DialogParameters')
% mdl = 'NOME_DO_MODELO';  load_system(mdl);
% for k = 1:24
%     n = N_h(k);
%     set_param([mdl '/Synchronous Machine'], 'NominalParameters', ...
%               sprintf('[%g %g %g]', Sn_maq_N(n), Vn_maq, fn));
%     set_param([mdl '/Three-phase Transformer'], ...
%               'NominalPower', sprintf('[%g %g]', S_trafo_N(n), fn), ...
%               'Winding1',     sprintf('[%g %g %g]', V_AT, R_eq_N(n)/2, X_eq_N(n)/2), ...
%               'Winding2',     sprintf('[%g %g %g]', V_BT, R_eq_N(n)/2, X_eq_N(n)/2));
%     % fator de carga da hora k (e festividade/banco se 18 <= h < 22): atualizar os Gains
%     % rodar o Load Flow do powergui e registrar Peo, V1..V4, perdas
% end
% Eventos dinamicos: C5 e C6 partem com N = 10 (reserva ja sincronizada, pior caso para o N-1);
% em C6 a perda de um bloco deixa N = 9 (36 unidades, Sn = 18,108 MVA, Pn = 14,49 MW).
 
%% 13) [REV] Maquina equivalente da simulacao: N_sim blocos em linha
% O bloco de reserva NAO e um ramo fisico no Simulink: a maquina e o trafo equivalentes
% sao reparametrizados para N_sim blocos (o cronograma N_h e a janela t_bk vem da Secao 12).
%   N_sim = 10 : caso base e festividade (C3), degrau C5 (reserva ja sincronizada)
%   N_sim = 9  : C6 (apos a perda de um bloco) ou horas fora de 18-22 h no despacho 9+1
assert(N_sim >= 1 && N_sim <= N_blocos, 'N_sim fora de 1..N_blocos');
Sn_maq  = Sn_maq_N(N_sim);   Pn_sim = Pn_N(N_sim);          % VA e W da maquina equivalente
S_trafo = S_trafo_N(N_sim);                                  % VA do trafo equivalente
Z_eq = Z_eq_own_N(N_sim);   Z_eq_100MVA = Z_eq100_N(N_sim);  % pu (base propria e 100 MVA)
R_eq = R_eq_N(N_sim);       X_eq = X_eq_N(N_sim);
R1 = R_eq/2;  R2 = R_eq/2;  L1 = X_eq/2;  L2 = X_eq/2;       % pu (bloco Three-Phase Transformer)
k_carreg   = Sn_maq/Pn_sim;                                  % Peo -> carregamento (pu da Prime): 1,25
k_kW       = Sn_maq/1e3;                                     % Peo -> kW
k_estab_pu = P_estab/Sn_maq;                                 % subtrair de Peo antes da Lookup Table
fprintf('--- Simulacao: N_sim = %d blocos (%d unidades) | Sn = %.3f MVA | Pn = %.2f MW | Z_eq = %.3f pu (100 MVA)\n', ...
        N_sim, 4*N_sim, Sn_maq/1e6, Pn_sim/1e6, Z_eq_100MVA);
 
%% 14) [REV] Eventos: disjuntor da festa/banco e bloco perdido (C6)
% Disjuntor da festa (e do banco, no mesmo ramo): no bloco, "Initial state" = fest_estado_ini
% e "Transition times" = t_fest_sim.
switch cenario
    case 'C2', t_fest_sim = t_fest*seg_por_hora;        % fecha 18 h, abre 22 h (curva de 24 h)
    case 'C5', t_fest_sim = t_evento;                   % fecha em t_evento
    otherwise, t_fest_sim = 1e3;                        % nao muda durante a simulacao
end
t_cap_sim = t_fest_sim;
 
% C6: perda de um bloco = a maquina de 9 blocos passa a suprir +P_bloco_perdido (1/10 da potencia da maquina em C3).
P_maq_C3 = 0.713*Sn_usina;                              % W (14,35 MW, medido no C5)
Q_maq_C3 = 3.9e6;                                       % var (~3,9 Mvar; refinar com Q_LF do Load Flow do C3)
P_bloco_perdido = P_maq_C3/N_blocos;                    % ~1,435 MW
Q_bloco_perdido = Q_maq_C3/N_blocos;                    % ~0,39 Mvar
metodo_C6 = 'resistivo';                                % 'resistivo' (adotado) ou 'negativo' (alternativa)
% (a) 'resistivo': Three-Phase Series RLC Load (so R, Y aterrado, Vn = Vn_carga, P = P_degrau) ligado em BG1
%     (barramento da maquina) por um Three-Phase Breaker: Initial state 0, Transition times = t_degrau_sim.
P_degrau = P_bloco_perdido;                             % W (o barramento BG1 fica em ~1,0 pu: P absorvida = P_degrau)
if evento_C6 && strcmp(metodo_C6,'resistivo'), t_degrau_sim = t_evento; else, t_degrau_sim = 1e3; end
% (b) 'negativo': Three-Phase Dynamic Load com [P Q] negativo em BG1, que vai a zero em t_evento
%     (Product com Step inicial 1 / final 0). Depende da dinamica da carga dinamica; nao adotado.
PQ_bloco_perdido = (evento_C6 && strcmp(metodo_C6,'negativo'))*[-P_bloco_perdido -Q_bloco_perdido];
 
%% 15) [REV] Limites de desempenho transitorio ISO 8528-5, classe G2 (Secao 4.3.1)
% Valores conforme as tabelas de [24] e [25] (fontes secundarias); confirmar na ISO 8528-5 [17].
G2_dF_aceit  = -10;     % %   queda transitoria de frequencia no aumento de carga
G2_dF_rej    = +12;     % %   elevacao transitoria de frequencia na rejeicao de carga
G2_t_rec     = 5;       % s   tempo de recuperacao da frequencia
G2_banda_rec = 2;       % %   faixa de recuperacao relacionada a frequencia
G2_f_min = fn*(1 + G2_dF_aceit/100);        % 54,0 Hz
G2_f_max = fn*(1 + G2_dF_rej/100);          % 67,2 Hz
G2_f_banda = fn*G2_banda_rec/100;           % +-1,2 Hz
% Uso: apos exportar t e w do scope, m = metricas_evento(t, w, 1, fn, [0.5 G2_banda_rec]);
%      atende = (m.nadir_Hz >= G2_f_min) && (m.trec_s(2) <= G2_t_rec);
 
clear k n Pg N idx_bk;      % limpa temporarios do despacho (o script roda no InitFcn)
