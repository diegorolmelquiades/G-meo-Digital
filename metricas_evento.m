function m = metricas_evento(t, w, t0, fn, banda_pct)
% METRICAS_EVENTO  Nadir, RoCoF, sobressinal e tempo de recuperacao da frequencia apos um degrau.
%   t, w      : tempo (s) e velocidade do rotor (pu), exportados do scope do sinal <Rotor speed wm (pu)>
%   t0        : instante do evento (s)            [C5 e C6: t0 = 1]
%   fn        : frequencia nominal (Hz)           [60]
%   banda_pct : faixa(s) de recuperacao, em % de fn  [padrao: 0,5 % e 2 %; G2 usa 2 %]
%
% Exportar do scope: Configuration Properties > Logging > "Log data to workspace"
% (nome ScopeData, formato "Structure With Time") e usar
%   t = ScopeData.time;  w = ScopeData.signals.values;
if nargin < 5, banda_pct = [0.5 2]; end
t = t(:);  f = fn*w(:);                                 % frequencia em Hz
i0 = find(t >= t0, 1);

[m.nadir_Hz, k] = min(f(i0:end));                       % nadir: minimo de f depois do degrau
m.t_nadir_s  = t(i0+k-1) - t0;
m.queda_pct  = 100*(m.nadir_Hz - fn)/fn;                % queda transitoria (limite G2: -10 %)
m.sobressinal_Hz = max(f(i0+k-1:end)) - fn;             % maximo acima de fn depois do nadir

j = find(t >= t0+0.1 & t <= t0+0.5);                    % janela de 0,4 s logo apos o degrau
p = polyfit(t(j), f(j), 1);
m.rocof_Hzs = abs(p(1));                                % inclinacao inicial da frequencia

m.banda_pct = banda_pct(:)';  m.trec_s = zeros(1, numel(banda_pct));
for q = 1:numel(banda_pct)                              % ultimo instante fora da faixa em torno de fn
    fora = find(abs(f(i0:end) - fn) > fn*banda_pct(q)/100, 1, 'last');
    if ~isempty(fora), m.trec_s(q) = t(i0+fora-1) - t0; end
end

fprintf('Nadir: %.2f Hz (%.2f %%) em %.2f s | RoCoF: %.2f Hz/s | sobressinal: %.2f Hz\n', ...
        m.nadir_Hz, m.queda_pct, m.t_nadir_s, m.rocof_Hzs, m.sobressinal_Hz);
for q = 1:numel(banda_pct)
    fprintf('trec (faixa +-%.1f %% = +-%.2f Hz): %.2f s\n', banda_pct(q), fn*banda_pct(q)/100, m.trec_s(q));
end
end
