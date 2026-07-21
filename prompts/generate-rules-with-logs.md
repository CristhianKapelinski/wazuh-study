# Prompt — Geração de Regras Wazuh a partir das Diretrizes da ACME-LAB

> Prompt **congelado** antes da rodada experimental. Não contém exemplos de log
> do dataset (para evitar vazamento) nem mapeamento explícito
> `cenário → severidade` (para evitar indução). A LLM deve **inferir** quais
> cenários merecem regras e qual severidade aplicar, a partir das diretrizes da
> organização, do catálogo de regras nativas e do contexto do Wazuh.
>
> A cada rodada, registrar: nome e versão do modelo, temperatura, seed (se
> disponível) e data.

---

## Tarefa

Você é um engenheiro de detecção sênior. Gere **regras customizadas do Wazuh**
(versão 4.14, formato XML) que **complementem** o ruleset nativo de modo a
refletir o contexto da organização descrita abaixo. A saída deve ser
**exclusivamente** o XML, dentro de um único `<group>`, sem texto fora do XML.
Comentários `<!-- ... -->` dentro do XML são permitidos para justificar cada
regra em uma linha.

## Contexto da organização

- Servidor de pesquisa acadêmica, acessado por SSH.
- Acesso legítimo vem **exclusivamente do Brasil**, pela rede institucional
  (faixas: `203.0.113.0/24`, `203.0.113.0/24`).
- **Sem horário comercial**: uso 24/7, inclusive madrugada e fins de semana.
- IP público; recebe tráfego externo contínuo (scans, força bruta).

Princípios declarados pela equipe:
- Geografia é o fator mais forte; acesso fora das faixas BR institucionais é anômalo.
- Horário **não eleva** severidade (uso contínuo).
- Impacto efetivo importa mais que tentativa.
- Volume/repetição da mesma origem é significativo.

## Escala de severidade adotada pela equipe

| Nível Wazuh | Rótulo |
|------------:|--------|
| 1–4 | baixo |
| 5–8 | médio |
| 9–12 | alto |
| 13–16 | crítico |

Use o atributo numérico `level="N"`.

## Catálogo de regras nativas relevantes (para encadear)

| ID | Lvl | Descrição |
|----|----:|-----------|
| 5715 | 3 | sshd: authentication success |
| 5710 | 5 | sshd: attempt to login using a non-existent user |
| 5716 / 5760 | 5 | sshd: authentication failed |
| 5712 | 10 | sshd: brute force, non-existent user |
| 5720 | 10 | sshd: multiple authentication failures |
| 5763 | 10 | sshd: brute force, authentication failed |
| 5402 | 3 | Successful sudo to ROOT |
| 5403 | 4 | First time user executed sudo |
| 5404 | 10 | 3 failed sudo attempts |
| 5302 | 5 | su: missed password to change UID to root |
| 5303 | 4 | su: successfully changed UID to root |
| 5501 / 5502 | 3 | PAM: session opened / closed |
| 5551 | 10 | PAM: multiple failed logins |
| 40101 | 12 | System user successfully logged to the system |
| 2504 | 9 | syslog: illegal root login |

Campos disponíveis no decoder sshd: `srcip`, `srcuser`, `dstuser`, `program_name`.

## Sintaxe de regras customizadas no Wazuh (referência técnica)

- IDs **≥ 100000** (faixa reservada para regras locais).
- Encadeamento: `<if_sid>` (atômica) ou `<if_matched_sid>` (correlação).
- Correlação usa `frequency="N" timeframe="S"` e modificadores como
  `<same_srcip/>`, `<same_user/>`, `<different_srcip/>`.
- Modificadores extras úteis: `<srcip>!203.0.113.0/24,!203.0.113.0/24</srcip>`
  (negação de faixa), `<time>...</time>`, `<weekday>...</weekday>`.

Exemplo **puramente técnico** de uma regra de correlação (os números são
ilustrativos — escolha valores justificados pelo contexto):

```xml
<rule id="100000" level="N" frequency="K" timeframe="T">
  <if_matched_sid>SID_NATIVO</if_matched_sid>
  <same_srcip />
  <description>...</description>
  <group>...,</group>
</rule>
```

## O que se espera de você

A partir das diretrizes da organização e do catálogo de regras nativas:

1. **Identifique** quais comportamentos merecem ser objeto de uma regra
   customizada (a equipe não lhe entrega essa lista — é parte da sua análise).
2. Para cada um, **decida**:
   - se é uma regra atômica (encadeada via `if_sid`) ou de correlação
     (via `if_matched_sid` + `frequency`/`timeframe`);
   - qual nível atribuir, justificando em comentário XML a relação com os
     princípios da organização;
   - quais modificadores (`<same_srcip/>`, faixas de IP, etc.) são necessários.
3. Garanta que IDs sejam únicos (≥ 100000) e que as regras não criem laços ou
   conflitos com o ruleset nativo.
4. Para regras de correlação, **justifique no comentário** o threshold
   escolhido (frequência e janela).

## Amostras de log (anonimizadas)

```
2026-05-17T04:11:00 srv01 sshd[123]: Accepted publickey for usr02 from 203.0.113.2 port 39838
2026-05-17T01:21:42 srv02 sshd[456]: Failed password for invalid user root from 198.51.100.1 port 35998
2026-05-17T06:26:22 srv02 su[2816]: pam_unix(su:session): session opened for user root(uid=0) by usr02(uid=1011)
2026-05-19T13:00:07 srv01 sshd[789]: Accepted publickey for usr03 from 198.51.100.42 port 53782
```

## Restrições de saída

- Apenas o XML, dentro de `<group name="acme-lab,local,"> ... </group>`.
- Nenhum texto antes ou depois do bloco XML.
- Não invente campos que não constam no decoder.
- Não use exemplos de log: a saída é puramente regras.
