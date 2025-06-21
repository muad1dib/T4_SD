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
![soma_inicio](https://github.com/user-attachments/assets/b7027a67-7fc4-4837-9501-190c18c9fcaf)
![soma_final](https://github.com/user-attachments/assets/31b46c4a-fc66-4e8c-9db0-56f81f940ba4)


#### Teste 2: Subtração Básica
![sub_in](https://github.com/user-attachments/assets/15183456-ff9c-4fdb-8f1e-825ceb129e98)
![sub_m](https://github.com/user-attachments/assets/b2e31262-d0e0-4a77-91b3-d0675f6e6b48)
![sub_res](https://github.com/user-attachments/assets/9be4e44f-ca79-41d6-b01f-bb94f34981b7)


#### Teste 3: Soma com Zero
![soma_0_in](https://github.com/user-attachments/assets/604f67f3-5a45-4475-ae30-59e1db82b2ab)
![soma_0_m](https://github.com/user-attachments/assets/0e12efad-c281-436a-8659-f8faf08a0574)
![soma_0_res](https://github.com/user-attachments/assets/4ba13095-ce90-4e83-95ce-6d9b0ce15f48)


#### Teste 4: Subtração com Resultado Zero
![sub=0_in](https://github.com/user-attachments/assets/1626c8b4-4978-49ea-a7d9-f5d3d825497e)
![sub=0_fin](https://github.com/user-attachments/assets/1ca4b34c-1da7-4814-9278-8244d3a17fc1)


#### Teste 5: Overflow
![of_in](https://github.com/user-attachments/assets/30e133df-76e3-47ff-9be6-cb4f8bfa1d7c)
![of_m](https://github.com/user-attachments/assets/a9529756-7f24-41f6-a118-f7cf77c517b2)
![of_fin](https://github.com/user-attachments/assets/905d85f7-338c-4e66-aa74-5a43d5222ae3)


#### Teste 6: Underflow
![under_in](https://github.com/user-attachments/assets/75452dd0-a7c1-45ed-b27c-14bd42083e16)
![under_m](https://github.com/user-attachments/assets/538dbfdc-7144-463f-bf1c-5634d074adf3)
![under_f](https://github.com/user-attachments/assets/3c5d5691-0e1e-438c-afcb-2c1a40ce643b)


#### Teste 7: Soma com Infinito
![soma_inf_in](https://github.com/user-attachments/assets/78a7b107-dfcc-4012-9986-a25944bbd290)
![soma_inf_m](https://github.com/user-attachments/assets/12bd5c22-1ad6-48c5-a843-94ce7284f52d)
![soma_inf_fin](https://github.com/user-attachments/assets/4281c767-815f-4104-9703-1b0eea913ba6)


#### Teste 8: Infinito - Infinito = NaN
![inf_sub_in](https://github.com/user-attachments/assets/afde8c32-cb40-4a4a-9bc5-dbfb44da15ca)
![inf_sub_m](https://github.com/user-attachments/assets/1cbea899-9a62-4032-b813-5b7655738f10)
![inf_sub_fin](https://github.com/user-attachments/assets/1fdf3f75-9694-421c-93a8-ce910d6a1546)


#### Teste 9: Arredondamento
![Screenshot_2025-06-20_21-28-38](https://github.com/user-attachments/assets/1d821a4a-1b6f-4361-81d9-b137bd2de239)
![Screenshot_2025-06-20_21-29-02](https://github.com/user-attachments/assets/034c4d3d-1c26-4c6e-81cf-cd293896037e)
![Screenshot_2025-06-20_21-29-16](https://github.com/user-attachments/assets/a047b156-ff35-4adc-989c-f86a7a877dbf)


#### Teste 10: Sinais Mistos
![Screenshot_2025-06-20_21-30-02](https://github.com/user-attachments/assets/6678f698-9871-456a-842a-ad6242bcf73d)
![Screenshot_2025-06-20_21-30-21](https://github.com/user-attachments/assets/a470f47c-9cf0-4168-ac4b-50def2335bc5)
![Screenshot_2025-06-20_21-30-32](https://github.com/user-attachments/assets/a149e4bf-b766-4ca1-8d2d-e3bfd9691f6c)


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






