library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity fpu_tb is
end fpu_tb;

architecture Behavioral of fpu_tb is
    component fpu
        Port (
            clk_100KHz : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            operation  : in  STD_LOGIC;
            Op_A_in    : in  STD_LOGIC_VECTOR(31 downto 0);
            Op_B_in    : in  STD_LOGIC_VECTOR(31 downto 0);
            data_out   : out STD_LOGIC_VECTOR(31 downto 0);
            status_out : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;
    

    signal clk      : STD_LOGIC := '0';
    signal reset    : STD_LOGIC := '0'; 
    signal operation: STD_LOGIC := '0';
    signal Op_A     : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal Op_B     : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal result   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal status   : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    

    alias INEXACT_FLAG   : std_logic is status(3);
    alias UNDERFLOW_FLAG : std_logic is status(2);
    alias OVERFLOW_FLAG  : std_logic is status(1);
    alias EXACT_FLAG     : std_logic is status(0);
    
    
    constant CLK_PERIOD : time := 10 us;
    constant X_BITS : integer := 9;
    constant Y_BITS : integer := 22;
    constant BIAS : integer := 255;
    
    constant EXP_ZERO : std_logic_vector(8 downto 0) := (others => '0');
    constant EXP_INF  : std_logic_vector(8 downto 0) := (others => '1');
    constant MANT_ZERO: std_logic_vector(21 downto 0) := (others => '0');
    

    function make_fp(sign: std_logic; exp: integer; mant_frac: real) return std_logic_vector is
        variable exp_vec : std_logic_vector(8 downto 0);
        variable mant_vec : std_logic_vector(21 downto 0);
        variable mant_int : integer;
    begin
        if exp = 0 then
            exp_vec := EXP_ZERO;
        elsif exp >= 511 then
            exp_vec := EXP_INF;
        else
            exp_vec := std_logic_vector(to_unsigned(exp, 9));
        end if;
        
        if mant_frac >= 1.0 then
            mant_vec := (others => '1');
        elsif mant_frac <= 0.0 then
            mant_vec := (others => '0');
        else
            mant_int := integer(mant_frac * (2.0**22));
            mant_vec := std_logic_vector(to_unsigned(mant_int, 22));
        end if;
        
        return sign & exp_vec & mant_vec;
    end function;
    
    function make_zero(sign: std_logic) return std_logic_vector is
    begin
        return sign & EXP_ZERO & MANT_ZERO;
    end function;
    
    function make_inf(sign: std_logic) return std_logic_vector is
    begin
        return sign & EXP_INF & MANT_ZERO;
    end function;
    
    function make_nan return std_logic_vector is
    begin
        return '0' & EXP_INF & ("0000000000000000000001");
    end function;

begin
    uut: fpu port map (
        clk_100KHz => clk,
        reset => reset,
        operation => operation,
        Op_A_in => Op_A,
        Op_B_in => Op_B,
        data_out => result,
        status_out => status
    );
    
    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;
    
    stim_proc: process
        variable l : line;
        
        procedure run_test(
            test_num : integer;
            description : string;
            op : std_logic;
            A : std_logic_vector(31 downto 0);
            B : std_logic_vector(31 downto 0);
            expected_result : std_logic_vector(31 downto 0);
            expected_status : std_logic_vector(3 downto 0)
        ) is
        begin
            operation <= op;
            Op_A <= A;
            Op_B <= B;
            
            wait until rising_edge(clk);
            wait for CLK_PERIOD/4; 
            
            write(l, string'("========================================"));
            writeline(output, l);
            write(l, string'("Teste "));
            write(l, test_num);
            write(l, string'(": "));
            write(l, description);
            writeline(output, l);
            
            write(l, string'("Op_A (hex): "));
            hwrite(l, A);
            write(l, string'(" | S:"));
            write(l, A(31));
            write(l, string'(" E:"));
            write(l, to_integer(unsigned(A(30 downto 22))));
            write(l, string'(" M:"));
            write(l, to_integer(unsigned(A(21 downto 0))));
            writeline(output, l);
            
            write(l, string'("Op_B (hex): "));
            hwrite(l, B);
            write(l, string'(" | S:"));
            write(l, B(31));
            write(l, string'(" E:"));
            write(l, to_integer(unsigned(B(30 downto 22))));
            write(l, string'(" M:"));
            write(l, to_integer(unsigned(B(21 downto 0))));
            writeline(output, l);
            
            write(l, string'("Resultado:  "));
            hwrite(l, result);
            write(l, string'(" | S:"));
            write(l, result(31));
            write(l, string'(" E:"));
            write(l, to_integer(unsigned(result(30 downto 22))));
            write(l, string'(" M:"));
            write(l, to_integer(unsigned(result(21 downto 0))));
            writeline(output, l);
            
            write(l, string'("Status: "));
            write(l, status);
            write(l, string'(" ["));
            if status(3) = '1' then write(l, string'("INEXACT ")); end if;
            if status(2) = '1' then write(l, string'("UNDERFLOW ")); end if;
            if status(1) = '1' then write(l, string'("OVERFLOW ")); end if;
            if status(0) = '1' then write(l, string'("EXACT")); end if;
            write(l, string'("]"));
            writeline(output, l);
            
            if result = expected_result then
                write(l, string'("RESULTADO: CORRETO"));
            else
                write(l, string'("RESULTADO: INCORRETO - Esperado: "));
                hwrite(l, expected_result);
            end if;
            writeline(output, l);
            
            if status = expected_status then
                write(l, string'("STATUS: CORRETO"));
            else
                write(l, string'("STATUS: INCORRETO - Esperado: "));
                write(l, expected_status);
                write(l, string'(" ["));
                if expected_status(3) = '1' then write(l, string'("INEXACT ")); end if;
                if expected_status(2) = '1' then write(l, string'("UNDERFLOW ")); end if;
                if expected_status(1) = '1' then write(l, string'("OVERFLOW ")); end if;
                if expected_status(0) = '1' then write(l, string'("EXACT")); end if;
                write(l, string'("]"));
            end if;
            writeline(output, l);
            writeline(output, l);
            
        end procedure;
        
    begin

        reset <= '0'; 
        operation <= '0';
        Op_A <= (others => '0');
        Op_B <= (others => '0');
        
        wait for CLK_PERIOD * 3;
        
        reset <= '1';
        wait for CLK_PERIOD * 2;
        
        write(l, string'("=== INICIO DOS TESTES FPU ==="));
        writeline(output, l);
        write(l, string'("Formato: 1 bit sinal + 9 bits expoente + 22 bits mantissa"));
        writeline(output, l);
        write(l, string'("BIAS = 255"));
        writeline(output, l);
        write(l, string'("Status bits: [3]INEXACT [2]UNDERFLOW [1]OVERFLOW [0]EXACT"));
        writeline(output, l);
        writeline(output, l);
        
        run_test(1, "Soma: 1.0 + 1.0 = 2.0 (EXACT)", '0',
                make_fp('0', BIAS, 0.0),     
                make_fp('0', BIAS, 0.0),     
                make_fp('0', BIAS+1, 0.0),   
                "0001"); 
        

        run_test(2, "Subtracao: 2.0 - 1.0 = 1.0 (EXACT)", '1',
                make_fp('0', BIAS+1, 0.0),   
                make_fp('0', BIAS, 0.0),     
                make_fp('0', BIAS, 0.0),     
                "0001"); 
        

        run_test(3, "Soma com zero: 5.0 + 0.0 = 5.0 (EXACT)", '0',
                make_fp('0', BIAS+2, 0.25),  
                make_zero('0'),              
                make_fp('0', BIAS+2, 0.25), 
                "0001"); 
        
        run_test(4, "Subtracao: 3.0 - 3.0 = 0.0 (EXACT)", '1',
                make_fp('0', BIAS+1, 0.5),   
                make_fp('0', BIAS+1, 0.5),   
                make_zero('0'),              
                "0001"); 
        
        run_test(5, "Overflow: num_grande + num_grande = +Inf", '0',
                make_fp('0', 510, 0.9),
                make_fp('0', 510, 0.9),
                make_inf('0'),
                "1010"); 
        
        run_test(6, "Underflow: num_pequeno - num_pequeno", '1',
                make_fp('0', 1, 0.1),
                make_fp('0', 1, 0.09),
                make_zero('0'),
                "1100"); 
        
        run_test(7, "Soma com infinito: +Inf + 5.0 = +Inf", '0',
                make_inf('0'),
                make_fp('0', BIAS+2, 0.25),
                make_inf('0'),
                "0001"); 
        
        run_test(8, "Caso especial: +Inf - +Inf = NaN", '1',
                make_inf('0'),
                make_inf('0'),
                make_nan,
                "0001"); 
        
        run_test(9, "Arredondamento: 1.0 + epsilon", '0',
                make_fp('0', BIAS, 0.0),
                make_fp('0', BIAS-25, 0.0),
                make_fp('0', BIAS, 0.0),
                "1000"); 
        
        run_test(10, "Sinais mistos: -5.0 - (-3.0) = -2.0", '1',
                make_fp('1', BIAS+2, 0.25),  
                make_fp('1', BIAS+1, 0.5),   
                make_fp('1', BIAS+1, 0.0),   
                "0001"); 
        
        write(l, string'("=== TESTES CONCLUIDOS ==="));
        writeline(output, l);
        
        wait for CLK_PERIOD * 5;
        
        write(l, string'("Simulacao finalizada."));
        writeline(output, l);
        
        wait; 
    end process;
    
end Behavioral;
