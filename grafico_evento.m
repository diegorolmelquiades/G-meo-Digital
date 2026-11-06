function grafico_evento(t, w, fn, f_min, banda_Hz, arquivo)
% GRAFICO_EVENTO  Resposta de frequencia a um evento, com o limite de queda e a faixa de recuperacao da classe G2.
%   t, w      : tempo (s) e velocidade do rotor (pu), do scope (ScopeData)
%   fn        : frequencia nominal (Hz)                 [60]
%   f_min     : limite de queda de frequencia (Hz)      [G2_f_min = 54,0]
%   banda_Hz  : faixa de recuperacao (Hz)               [G2_f_banda = 1,2]
%   arquivo   : nome do PNG a salvar (opcional)         ['C5_frequencia.png']
% Uso (depois da simulacao, no Command Window; NAO colocar no InitFcn):
%   grafico_evento(ScopeData.time, ScopeData.signals.values, fn, G2_f_min, G2_f_banda, 'C5_frequencia.png')
if nargin < 6, arquivo = 'C5_frequencia.png'; end
f = fn*w(:);
figure; hold on; grid on
plot(t, f, 'LineWidth', 1.6);
yline(fn, ':k');                                   % frequencia nominal
yline(f_min, '--r');                               % limite de queda G2
yline(fn + banda_Hz, '-.b');                       % faixa de recuperacao (superior)
yline(fn - banda_Hz, '-.b');                       % faixa de recuperacao (inferior)
xlabel('Tempo (s)'); ylabel('Frequencia (Hz)'); xlim([0 max(t)]);
legend('Frequencia', 'Nominal (60 Hz)', 'Limite de queda G2', 'Faixa de recuperacao G2 (2 %)', ...
       'Location', 'southeast');
exportgraphics(gcf, arquivo, 'Resolution', 300);
fprintf('Grafico salvo em %s\n', arquivo);
end
