%% dados_cenarios.m
% Gêmeo Digital - Ficha B4 (grupo gerador diesel, sistema isolado)
% Usina escalada a partir de Apuí: 40 x UTE 550 + 10 transformadores.
% Rodar antes da simulação ou chamar no InitFcn: run('dados_cenarios.m');
% Convenção de tempo: seg_por_hora segundos simulados = 1 hora.
 
%% 1) Solver e escala de tempo
Ts = 5e-5;                    % s. Só é usado se o powergui voltar ao modo Discrete.
seg_por_hora = 1;             % 1s corresponde a 1h
 
%% 2) Curva de carga 24 h (arquivo do professor)
T            = readtable('curva_carga_24h.csv');   % na pasta do modelo
horas        = double(T.hora(:));                  % 0..23 (em horas)
fator        = double(T.fator_carga(:));           % média = 0,804
perfil_carga = [horas*seg_por_hora fator];         % Nx2 (tempo simulado, fator) -> From Workspace
assert(size(perfil_carga,1)==24 && size(perfil_carga,2)==2 && ...
       ~any(isnan(perfil_carga(:))), 'perfil_carga inválido: confira o CSV');
 
%% 3) Geradores UTE 550 (regime Prime, catálogo)
S_unit   = 503e3;             % VA por gerador (Prime)
P_unit   = 0.8*S_unit;        % W, ~402 kW (FP nominal 0,8)
N_ativos = 40;                % 10 blocos x 4 geradores  [ASSUNÇÃO de projeto]
Sn_usina = N_ativos*S_unit;   % 20,12 MVA
Pn_usina = N_ativos*P_unit;   % 16,10 MW
 
%% 4) Máquina síncrona equivalente (Synchronous Machine pu Fundamental)
Sn_maq = Sn_usina;            % VA
Vn_maq = 13.8e3;      % V. Máquina equivalente referida ao lado de 13,8 kV
                      % Nota: a usina real gera em 0,48 kV e eleva para 13,8 kV (trafos Dyn1).
                      % No modelo o gerador é referido ao lado de 13,8 kV (relação 13,8/13,8 kV),
                      % mantendo a impedância Z_eq em pu na base de 20,5 MVA.

fn     = 60;                  % Hz
polos  = 4;                   % 1800 rpm @ 60 Hz
% Parâmetros em pu: valores de referência da literatura (Dong et al.,
% Energies 2023, Tab. 1). Não são do alternador WEG real. [ASSUNÇÃO]
Xd = 1.346; Xq = 0.940; Xd_t = 0.446; Xd_st = 0.330; Xq_st = 0.370;
Xl = 0.243; Td0_t = 1.660; Td0_st = 0.118; Tq0_st = 0.035; Rs = 0.006;
% Inércia: J do alternador = 5,78 kg.m2 (só o alternador)
w_mec  = 2*pi*fn/(polos/2);                 % rad/s
H_alt  = 0.5*5.78*w_mec^2/S_unit;           % ~0,20 s (sem motor/volante)
H_maq  = 1.2;                 % s. Valor de referência (Dong et al.); ajustar
                              % se obtiver o J do conjunto motor+alternador
 
%% 5) Transformadores (Apuí real + acrescentados)
S_tr = [2000 2000 2000 2000 2500  2000 2000 2000 2000 2000]*1e3;   % VA
Z_tr = [7.10 7.03 6.86 6.90 6.90  6.97 6.97 6.97 6.97 6.97]/100;   % pu, base própria
% Unidades 1-5 = placa real; 6-10 = acrescentadas, Z = média das 2000 kVA [ASSUNÇÃO]
S_trafo = sum(S_tr);                        % 20,5 MVA
Z_eq    = S_trafo/sum(S_tr./Z_tr);          % 0,0696 pu na base S_trafo (paralelo)
Z_eq_100MVA = Z_eq*100e6/S_trafo;           % 0,340 pu na base 100 MVA
XR   = 10;                                  % relação X/R
R_eq = Z_eq/sqrt(1+XR^2);
X_eq = XR*R_eq;
R1 = R_eq/2;  R2 = R_eq/2;                  % pu (bloco Three-Phase Transformer)
L1 = X_eq/2;  L2 = X_eq/2;                  % pu
V_AT = 13.8e3;  V_BT = 13.8e3;              % V (modelo). Valor real do secundário: 480 V
Rm = 500;  Lm = 500;                        % pu, ramo de magnetização [ASSUNÇÃO]
 
%% 6) Cargas (barras 2, 3 e 4) - Three-Phase Dynamic Load, porta PQ
FP        = 0.95;                           % Fator adotado
Vn_carga  = 13.8e3;                         % V, barras de carga na AT
P_pico    = 12e6;                           % W, pico da curva base (fator = 1,0)
shares    = [0.5 0.3 0.2];                  % divisão entre cargas 1, 2, 3
P_base    = shares(1)*P_pico;               % 6,0 MW -> Gain P (carga 1)
Q_base    = P_base*tan(acos(FP));           % Gain Q (carga 1)
k2        = shares(2)/shares(1);            % 0,6 -> Gain escalar da carga 2
k3        = shares(3)/shares(1);            % 0,4 -> Gain escalar da carga 3
 
%% 7) Cenário extraordinário: festividade (barra 4)
P_fest = 2e6;                               % W [ASSUNÇÃO]
Q_fest = P_fest*tan(acos(FP));              % var
t_fest = [18 22];                           % 18 22 h: Breaker fecha em 18, abre em 22
t_fest_sim = t_fest*seg_por_hora;           % s simulados -> Transition times do Breaker
% Three-Phase Parallel RLC Load na barra 4: [Vn_carga fn], P = P_fest, QL = Q_fest
 
%% 8) Limites e alarmes
V_min = 0.95;  V_max = 1.05;                % pu (PRODIST)
carreg_max = 1.0;                           % P_ger/Pn_usina
 
%% 9) Consumo específico (1-D Lookup Table) - entrada: P_ger/Pn_usina
cons_bp      = [0.10 0.25 0.50 0.75 1.00];
k_cons       = 0.84;    % reescala p/ ~0,237 L/kWh a 80% (catálogo: 230-244 L/MWh no COP)
cons_tab     = k_cons*[0.50 0.38 0.30 0.283 0.28];   % L/kWh (forma da curva: literatura)
preco_diesel = 7.50;    % R$/L
% Ganhos da cadeia de consumo no Simulink (a partir do sinal Peo, pu da máquina):
k_carreg    = Sn_maq/Pn_usina;   % Gain: Peo -> carregamento da usina (pu), ~1,25
k_kW        = Sn_maq/1e3;        % Gain: Peo -> potência ativa (kW)
ganho_tempo = 1/seg_por_hora;    % Gain antes do Integrator (s simulados -> horas)
 
%% 10) Verificações da curva de carga
h   = horas;                                % horas do dia (0..23)
P_h = P_pico*perfil_carga(:,2) + P_fest*(h>=t_fest(1) & h<t_fest(2));
fprintf('Pico: %.2f MW | Media: %.2f MW\n', max(P_h)/1e6, mean(P_h)/1e6);
fprintf('Carregamento no pico: %.1f%% (kW) | %.1f%% (kVA)\n', ...
        100*max(P_h)/Pn_usina, 100*max(P_h)/FP/Sn_usina);
fprintf('Carregamento medio: %.1f%% (limite Prime: 70%%)\n', 100*mean(P_h)/Pn_usina);
fprintf('Trafo: %.1f%% no pico | Z_eq = %.4f pu (%.3f pu em 100 MVA)\n', ...
        100*max(P_h)/FP/S_trafo, Z_eq, Z_eq_100MVA);
if max(P_h) > Pn_usina,        warning('Pico acima da potência Prime da usina.'); end
if mean(P_h) > 0.70*Pn_usina,  warning('Média diária acima de 70%% do Prime.');   end
% N-1 (perda de um bloco de 4 geradores): Pn_usina - 4*P_unit = 14,49 MW
 
%% 11) Consumo de diesel e custo diário (cálculo de referência p/ validar o modelo)
% Reproduz, fora do Simulink, o que a Lookup Table + Integrador vão calcular
% dentro do modelo -- serve de "gabarito" para a Camada 4 (Passo 5c).
carreg_h  = P_h/Pn_usina;                                    % carregamento por hora (pu)
cons_h    = interp1(cons_bp, cons_tab, carreg_h, 'linear');  % L/kWh por hora
E_h_kWh   = P_h/1e3;                                         % kWh na hora (duração = 1 h)
L_h       = cons_h.*E_h_kWh;                                 % L consumidos naquela hora
L_dia     = sum(L_h);                                        % L/dia
custo_dia = L_dia*preco_diesel;                              % R$/dia
cons_medio = L_dia/sum(E_h_kWh);                             % L/kWh médio do dia
fprintf('--- Consumo e custo (referencia de calculo) ---\n');
fprintf('Consumo especifico medio do dia: %.3f L/kWh\n', cons_medio);
fprintf('Consumo de diesel: %.0f L/dia\n', L_dia);
fprintf('Custo de combustivel: R$ %.2f/dia (preco: R$ %.2f/L)\n', custo_dia, preco_diesel);