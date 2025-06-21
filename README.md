# FPU Simplificada - Sistema de Ponto Flutuante
## Trabalho 4 - Sistemas Digitais 2025-1 - 21 de Junho de 2025

### Informações do Projeto
- **Disciplina:** Sistemas Digitais 
- **Professor:** Anderson Domingues
- **Aluno:** Marcelo Henrique Fernandes
- **Matrícula:** 18111269-9

---

## 1. Cálculo dos Parâmetros de Projeto

### Determinação de X e Y

Com base na minha matrícula **18111269-9**:

- **Soma dos dígitos:** 1 + 8 + 1 + 1 + 1 + 2 + 6 + 9 = 29
- **Dígito verificador:** 9 (ímpar) → utilizar sinal **+**
- **Cálculo de X:** X = [8 + 29 mod 4] = [8 + 1] = **9 bits**
- **Cálculo de Y:** Y = 31 - X = 31 - 9 = **22 bits**

### Formato do Número de Ponto Flutuante


```
|31|30    22|21                0|
|S |   EXP   |      MANTISSA    |
|1 | 9 bits  |     22 bits      |
```

- **Sinal (S):** 1 bit (posição 31)
- **Expoente:** 9 bits (posições 30-22)
- **Mantissa:** 22 bits (posições 21-0)
- **BIAS:** 255 (2^8 - 1)

---

## 2. Espectro Numérico Representável

### Características do Sistema

- **Bias:** 255
- **Expoente:** 0 a 511 (9 bits)
- **Mantissa:** 0 a 4.194.303 (22 bits)

### Valores Especiais

| Expoente | Mantissa | Valor |
|----------|----------|--------|
| 0 | 0 | ±0 |
| 0 | ≠0 | Números denormalizados |
| 1-510 | qualquer | Números normalizados |
| 511 | 0 | ±∞ |
| 511 | ≠0 | NaN |

### Faixas Numéricas

- **Menor número normalizado positivo:** 2^(1-255) ≈ 5.4 × 10^-77
- **Maior número normalizado positivo:** (2-2^-22) × 2^(510-255) ≈ 1.7 × 10^77
- **Precisão:** 22 bits de mantissa ≈ 6.6 dígitos decimais

---

## 3. Implementação em VHDL

### Arquitetura Geral

A FPU foi implementada usando uma arquitetura síncrona com processo único que trata todas as operações de ponto flutuante.  A implementação utiliza vetores de bits (`std_logic_vector`) e operações aritméticas com tipos `unsigned` para garantir comportamento determinístico, além do padrão IEEE-754.

### Detecção de Condições de Status
A implementação identifica os diferentes status através de variáveis booleanas que são convertidas em bits de saída:

```vhdl
variable has_inexact : boolean;
variable has_overflow : boolean;
variable has_underflow : boolean;
variable has_exact : boolean;
variable bits_lost : boolean;

status_out_reg(3) <= '1' when has_inexact else '0';
status_out_reg(2) <= '1' when has_underflow else '0';
status_out_reg(1) <= '1' when has_overflow else '0';
status_out_reg(0) <= '1' when has_exact else '0';
```

#### EXACT
Detectado quando:
- Nenhum bit é perdido durante o alinhamento
- Os guard bits são todos zero
- Não ocorre overflow nem underflow

```vhdl
if guard_bits = "000" and not bits_lost then
    has_exact := true;
else
    has_inexact := true;
end if;
```

#### OVERFLOW  
Detectado quando:
- O expoente resultado seria ≥ 511
- Operações de soma com expoentes altos (≥ 510)

```vhdl
if exp_result_final >= 511 then
    would_be_overflow := true;
elsif original_exp_result >= 510 and effective_operation = '0' then
    would_be_overflow := true;
end if;
```

#### UNDERFLOW
Detectado quando:
- O expoente resultado seria ≤ 0
- Subtrações com expoentes baixos que resultem em normalização excessiva

```vhdl
if exp_result_final <= 0 then
    would_be_underflow := true;
elsif original_exp_result <= 2 and effective_operation = '1' then
    if leading_zeros > original_exp_result then
        would_be_underflow := true;
    end if;
end if;
```

#### INEXACT
Detectado quando:
- Bits são perdidos durante o alinhamento de mantissas
- Guard bits não são zero após a operação
- Ocorre overflow ou underflow

```vhdl
if guard_bits = "000" and not bits_lost then
    has_exact := true;
else
    has_inexact := true;
end if;
```

---

## 4. Problemas Identificados e Soluções

### Problemas Principais

Durante o desenvolvimento, foram identificados vários problemas críticos na implementação:

1. **Contradição nos Testes 5 e 6:** Os testes finais consideravam correto ter simultaneamente flags OVERFLOW e UNDERFLOW ativados, o que é contraditório. Um número não pode ser ao mesmo tempo muito grande (overflow) e muito pequeno (underflow). Tal erro persistia por má compreensão de minha parte e dos bits utilizados na implementação.

2. **Sinais Não Inicializados:** Vários sinais internos não eram inicializados adequadamente, causando valores 'X' (indefinidos) nas simulações.

3. **Lógica de Normalização Incorreta:** A detecção de leading zeros e o processo de normalização não funcionavam corretamente para todos os casos.

4. **Tratamento Inadequado de Casos Especiais:** Zero, infinito e NaN não eram tratados corretamente, causando resultados incorretos.

### Soluções Implementadas

- **Inicialização Completa:** Todos os sinais e variáveis foram inicializados adequadamente
- **Lógica de Status Corrigida:** Implementação mutuamente exclusiva para OVERFLOW/UNDERFLOW
- **Tratamento de Casos Especiais:** Implementação completa para zero, infinito e NaN, reescrevendo código

---

## 5. Testbench e Validação

### 5.1 Metodologia de Teste

O testbench foi desenvolvido com 10 casos de teste que cobrem:

### Teste 1: Soma Básica (1.0 + 1.0 = 2.0)
Verifica a operação de soma mais simples, testando se a FPU consegue somar dois números iguais.

### Teste 2: Subtração Básica (2.0 - 1.0 = 1.0)
Testa a operação de subtração com números de magnitudes diferentes.

### Teste 3: Soma com Zero (5.0 + 0.0 = 5.0)
Verifica o tratamento do elemento neutro da soma.

### Teste 4: Subtração com Resultado Zero (3.0 - 3.0 = 0.0)
Testa se a subtração de números iguais resulta corretamente em zero.

### Teste 5: Overflow
Verifica se a FPU detecta corretamente quando o resultado excede o maior número representável.

### Teste 6: Underflow
Testa a detecção de underflow quando o resultado é menor que o menor número normalizado representável.

### Teste 7: Soma com Infinito
Verifica o comportamento quando um dos operandos é infinito.

### Teste 8: Infinito - Infinito = NaN
Testa o caso especial que resulta em "Not a Number".

### Teste 9: Arredondamento
Verifica se a FPU detecta corretamente quando há perda de precisão.

### Teste 10: Sinais Mistos
Testa operações com números negativos e positivos.

### 5.2 Função de Criação de Números

O testbench utiliza uma função auxiliar para criar números de ponto flutuante:
```vhdl
function make_fp(sign: std_logic; exp: integer; mant_frac: real) return std_logic_vector
```

### 5.3 Estrutura dos Testes

Cada teste segue a estrutura:
1. **Configuração** dos operandos A e B
2. **Definição** da operação (soma ou subtração)
3. **Execução** de um ciclo de clock
4. **Verificação** do resultado e status
5. **Relatório** detalhado com valores esperados vs obtidos

---

## 6. Resultados dos Testes

### Imagens dos Testes

#### Teste 1: Soma Básica
![soma_final](https://github.com/user-attachments/assets/31b46c4a-fc66-4e8c-9db0-56f81f940ba4)


#### Teste 2: Subtração Básica


#### Teste 3: Soma com Zero


#### Teste 4: Subtração com Resultado Zero


#### Teste 5: Overflow


#### Teste 6: Underflow


#### Teste 7: Soma com Infinito


#### Teste 8: Infinito - Infinito = NaN


#### Teste 9: Arredondamento

#### Teste 10: Sinais Mistos


---

## 7. Como Executar no Questa/ModelSim

1. Abra o Questa/ModelSim
2. No console, navegue até o diretório:
   ```
   cd /caminho/para/T4_SD
   ```
3. Execute o script de simulação:
   ```
   do sim.do
   ```

---

## 8. Conclusões

A implementação da FPU simplificada demonstrou a complexidade inerente ao processamento de números de ponto flutuante. Os principais desafios enfrentados foram:

1. **Gerenciamento de Precisão:** Detectar corretamente quando há perda de precisão
2. **Casos Especiais:** Tratar adequadamente zero, infinito e NaN
3. **Overflow/Underflow:** Identificar corretamente quando os resultados excedem os limites
4. **Normalização:** Implementar algoritmos eficientes para normalização de mantissas

O projeto aparenta ter sucesso em implementar uma FPU funcional que atende aos requisitos especificados, com tratamento adequado de casos especiais e detecção correta das condições de status.

---

## 9. Arquivos do Projeto

- `fpu_Mod.vhdl`: Módulo principal da FPU
- `tb_fpu.vhdl`: Testbench com 10 casos de teste
- `sim.do`: Script de simulação
- `README.md`: Documentação do projeto

---

## 10. Referências

- Material da disciplina Sistemas Digitais
- Padrão IEEE-754 para Aritmética de Ponto Flutuante da Oracle (providenciado no Enunciado)
- Documentação do ModelSim/QuestaSim, para auxiliar nos testes com outros tempos no clock






