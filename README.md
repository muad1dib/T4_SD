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
![soma_final](https://github.com/user-attachments/assets/438c4e64-d3c1-478b-905b-8e1e973dbb38)
![soma_inicio](https://github.com/user-attachments/assets/34c0e90e-67dc-4b0d-a01d-96f09f821af5)

#### Teste 2: Subtração Básica
![sub_in](https://github.com/user-attachments/assets/8a597b1d-7fe3-4082-bcd6-8911626efe9c)
![sub_m](https://github.com/user-attachments/assets/0c62b401-757a-4a02-a631-e2dff06c38f4)
![sub_res](https://github.com/user-attachments/assets/c8a8acd5-0524-4694-9890-e0f25bb98504)

#### Teste 3: Soma com Zero
![soma_0_in](https://github.com/user-attachments/assets/aedfb576-39f3-4e7d-aade-a08201dcca1f)
![soma_0_m](https://github.com/user-attachments/assets/5154f327-62ad-4ecd-9988-9104b4df7a68)
![soma_0_res](https://github.com/user-attachments/assets/5bb49248-2513-4cbe-a119-e1ef4afa346e)

#### Teste 4: Subtração com Resultado Zero
![sub=0_in](https://github.com/user-attachments/assets/c3935f86-2fda-4407-b1fe-67b878730a4c)
![sub=0_fin](https://github.com/user-attachments/assets/8be5f636-5e15-4e15-a9d9-b2c5a6f679ac)

#### Teste 5: Overflow
![of_in](https://github.com/user-attachments/assets/7bfce21a-8be8-4438-986b-79c58c2f1430)
![of_m](https://github.com/user-attachments/assets/0b24c6c5-19b1-4e56-8395-e2616b6104e6)
![of_fin](https://github.com/user-attachments/assets/188fdaf2-1f12-4133-b36b-207638648f5b)

#### Teste 6: Underflow
![under_in](https://github.com/user-attachments/assets/16eb3ea0-f1f3-4b64-967e-a793ac5431cb)
![under_m](https://github.com/user-attachments/assets/4071f18a-8669-4361-b96e-1c10bdff3341)
![under_f](https://github.com/user-attachments/assets/88d8c4aa-a95c-4478-8f82-9a116d5e2ef9)

#### Teste 7: Soma com Infinito
![soma_inf_m](https://github.com/user-attachments/assets/3b236437-aa3c-4ff0-accf-7f9b6efc70d3)
![soma_inf_in](https://github.com/user-attachments/assets/ca553462-fb25-43db-bc3d-d71356a5b34d)
![soma_inf_fin](https://github.com/user-attachments/assets/239e927a-1465-4f27-b310-ccc2d6791f7c)

#### Teste 8: Infinito - Infinito = NaN
![inf_sub_m](https://github.com/user-attachments/assets/0417298f-4a79-4d35-9b55-9430072792f3)
![inf_sub_in](https://github.com/user-attachments/assets/2660d7a8-4c2c-44cb-86fe-20367f81e3ad)
![inf_sub_fin](https://github.com/user-attachments/assets/7489d099-9d8d-4906-a4cc-1560d1961e83)

#### Teste 9: Arredondamento
![Screenshot_2025-06-20_21-29-16](https://github.com/user-attachments/assets/ddec9012-6fd0-426b-86be-97fdab626dc7)
![Screenshot_2025-06-20_21-29-02](https://github.com/user-attachments/assets/a37db37f-8825-4950-be8c-28db10c155b4)
![Screenshot_2025-06-20_21-28-38](https://github.com/user-attachments/assets/26d1b25b-a95c-44b6-ba6c-3f96c83f6a4e)

#### Teste 10: Sinais Mistos
![Screenshot_2025-06-20_21-30-32](https://github.com/user-attachments/assets/45198c96-4d71-4630-94a3-562238d8b405)
![Screenshot_2025-06-20_21-30-21](https://github.com/user-attachments/assets/12bf52d8-a1c4-4ba1-b4b2-efdbf0fc2e54)
![Screenshot_2025-06-20_21-30-02](https://github.com/user-attachments/assets/c28fca71-b24a-41da-b7ae-01b2bdbc2c4e)

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






