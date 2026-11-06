% RODAR_SENSIBILIDADE_H  Roda o cenario atual (C5 ou C6) para varios valores de H e imprime as metricas.
% NAO TESTADO no seu modelo: se der erro, rode manualmente (trocar H_maq, rodar o script, simular).
% Pre-requisitos: modelo aberto; cenario escolhido na Secao 0 de dados_cenarios.m; Load Flow ja aplicado;
% ramos do evento DESCOMENTADOS (C5: festa+banco; C6: degrau); scope da velocidade com log "ScopeData"
% (Structure With Time). Este arquivo e um SCRIPT (executar no Command Window, nao no InitFcn).
mdl   = bdroot;                       % modelo atual. Se der erro: mdl = 'NOME_DO_MODELO';
eval(get_param(mdl, 'InitFcn'));      % roda o MESMO script do InitFcn do modelo (define cenario, t_evento, fn, G2_*)
if ~any(strcmp(cenario, {'C5','C6'}))
    error('Defina cenario = ''C5'' ou ''C6'' na Secao 0 de dados_cenarios.m (cenario atual: %s).', cenario);   % se 'cenario' nao existir: o InitFcn chama outro arquivo
end
set_param(mdl, 'FastRestart', 'off'); % com Fast Restart ligado, parametros nao sintonizaveis ficam desatualizados
Hs    = [0.5 1.0 1.2 1.5];            % inclui 1,2 s para a figura comparativa (e como conferencia)
Tstop = '20';
curvas = cell(1, numel(Hs));
tab   = nan(numel(Hs), 6);            % H | nadir (Hz) | RoCoF (Hz/s) | trec 2 % (s) | sobressinal (Hz) | atende
for i = 1:numel(Hs)
    assignin('base', 'H_sens', Hs(i));                 % dados_cenarios.m (InitFcn) usa H_sens se existir
    simOut = sim(mdl, 'StopTime', Tstop);
    try,   SD = simOut.get('ScopeData');               % dados do scope vindos da simulacao
    catch, SD = evalin('base', 'ScopeData');           % ou da variavel no workspace
    end
    t = SD.time;  w = SD.signals.values;
    curvas{i} = [t(:) fn*w(:)];                         % guarda a frequencia (Hz) para a figura
    m = metricas_evento(t, w, t_evento, fn, [0.5 G2_banda_rec]);
    tab(i,:) = [Hs(i) m.nadir_Hz m.rocof_Hzs m.trec_s(2) m.sobressinal_Hz ...
                double(m.nadir_Hz >= G2_f_min && m.trec_s(2) <= G2_t_rec)];
end
evalin('base', 'clear H_sens');                        % volta ao H_maq = 1,2 s
fprintf('\n  H(s)  nadir(Hz)  RoCoF(Hz/s)  trec2%%(s)  sobre(Hz)  atende G2\n');
fprintf('  %4.1f   %8.2f   %9.2f   %8.2f   %8.2f   %d\n', tab');

% Figura comparativa da sensibilidade de H (com os limites G2)
figure; hold on; grid on
for i = 1:numel(Hs), plot(curvas{i}(:,1), curvas{i}(:,2), 'LineWidth', 1.4); end
yline(fn, ':k');  yline(G2_f_min, '--r');  yline(fn+G2_f_banda, '-.b');  yline(fn-G2_f_banda, '-.b');
xlabel('Tempo (s)');  ylabel('Frequencia (Hz)');  xlim([0 20]);  ylim([53 63]);
legend([arrayfun(@(h) sprintf('H = %.1f s', h), Hs, 'UniformOutput', false), ...
        {'Nominal (60 Hz)', 'Limite de queda G2', 'Faixa de recuperacao G2 (2 %)'}], 'Location', 'southeast');
exportgraphics(gcf, ['sensibilidade_H_' cenario '.png'], 'Resolution', 300);
fprintf('Figura salva em sensibilidade_H_%s.png\n', cenario);
