library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fpu is
    Port (
        clk_100KHz  : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        Op_A_in     : in  STD_LOGIC_VECTOR(31 downto 0);
        Op_B_in     : in  STD_LOGIC_VECTOR(31 downto 0);
        operation   : in  STD_LOGIC; 
        data_out    : out STD_LOGIC_VECTOR(31 downto 0);
        status_out  : out STD_LOGIC_VECTOR(3 downto 0)
    );
end fpu;

architecture Behavioral of fpu is
    constant X_BITS : integer := 9;
    constant Y_BITS : integer := 22;
    constant BIAS   : integer := 255; 
    
    constant ZERO_EXP: unsigned(8 downto 0) := (others => '0');
    constant INF_EXP : unsigned(8 downto 0) := (others => '1');
    constant MAX_EXP : unsigned(8 downto 0) := "111111110"; 
    constant ZERO_MANT: unsigned(21 downto 0) := (others => '0');
    
    signal data_out_reg : STD_LOGIC_VECTOR(31 downto 0);
    signal status_out_reg : STD_LOGIC_VECTOR(3 downto 0);
    
    signal sign_a, sign_b : std_logic;
    signal exp_a, exp_b   : unsigned(8 downto 0);
    signal mant_a, mant_b : unsigned(21 downto 0);
    
    signal effective_sign_b : std_logic;
    signal effective_operation : std_logic; 
    
    signal is_zero_a, is_zero_b : std_logic;
    signal is_inf_a, is_inf_b   : std_logic;
    signal is_nan_a, is_nan_b   : std_logic;

begin
    data_out <= data_out_reg;
    status_out <= status_out_reg;
    
    sign_a <= Op_A_in(31);
    sign_b <= Op_B_in(31);
    exp_a <= unsigned(Op_A_in(30 downto 22));
    exp_b <= unsigned(Op_B_in(30 downto 22));
    mant_a <= unsigned(Op_A_in(21 downto 0));
    mant_b <= unsigned(Op_B_in(21 downto 0));
    
    effective_sign_b <= sign_b xor operation;
    effective_operation <= sign_a xor effective_sign_b;
    
    is_zero_a <= '1' when (exp_a = ZERO_EXP and mant_a = ZERO_MANT) else '0';
    is_zero_b <= '1' when (exp_b = ZERO_EXP and mant_b = ZERO_MANT) else '0';
    is_inf_a <= '1' when (exp_a = INF_EXP and mant_a = ZERO_MANT) else '0';
    is_inf_b <= '1' when (exp_b = INF_EXP and mant_b = ZERO_MANT) else '0';
    is_nan_a <= '1' when (exp_a = INF_EXP and mant_a /= ZERO_MANT) else '0';
    is_nan_b <= '1' when (exp_b = INF_EXP and mant_b /= ZERO_MANT) else '0';
    
    process(clk_100KHz, reset)
        variable exp_diff : integer;
        variable exp_result : integer;
        variable a_larger : std_logic;
        
        variable mant_a_norm, mant_b_norm : unsigned(22 downto 0);
        variable mant_a_ext, mant_b_ext   : unsigned(25 downto 0);
        variable mant_a_aligned, mant_b_aligned : unsigned(25 downto 0);
        
        variable mant_result_raw : unsigned(26 downto 0);
        variable sign_result : std_logic;
        variable mant_result_final : unsigned(21 downto 0);
        variable exp_result_final : integer;
        
        variable shift_amount : integer;
        variable leading_zeros : integer;
        variable guard_bits : unsigned(2 downto 0);
        variable temp_result : std_logic_vector(31 downto 0);
        
        variable has_inexact : boolean;
        variable has_overflow : boolean;
        variable has_underflow : boolean;
        variable has_exact : boolean;
        variable bits_lost : boolean;
        
        variable original_exp_result : integer;
        variable would_be_overflow : boolean;
        variable would_be_underflow : boolean;
        
    begin
        if reset = '0' then
            data_out_reg <= (others => '0');
            status_out_reg <= "0001"; 
            
        elsif rising_edge(clk_100KHz) then
            has_exact := false;
            has_overflow := false;
            has_underflow := false;
            has_inexact := false;
            bits_lost := false;
            would_be_overflow := false;
            would_be_underflow := false;
            
            temp_result := (others => '0');
            sign_result := '0';
            
            if is_nan_a = '1' or is_nan_b = '1' then
                temp_result := '0' & std_logic_vector(INF_EXP) & "0000000000000000000001";
                has_exact := true;
                
            elsif is_inf_a = '1' or is_inf_b = '1' then
                if is_inf_a = '1' and is_inf_b = '1' then
                    if effective_operation = '1' then 
                        temp_result := '0' & std_logic_vector(INF_EXP) & "0000000000000000000001"; 
                        has_exact := true;
                    else 
                        temp_result := sign_a & std_logic_vector(INF_EXP) & std_logic_vector(ZERO_MANT);
                        has_exact := true;
                    end if;
                elsif is_inf_a = '1' then
                    temp_result := sign_a & std_logic_vector(INF_EXP) & std_logic_vector(ZERO_MANT);
                    has_exact := true;
                else 
                    temp_result := effective_sign_b & std_logic_vector(INF_EXP) & std_logic_vector(ZERO_MANT);
                    has_exact := true;
                end if;
                
            elsif is_zero_a = '1' and is_zero_b = '1' then
                temp_result := (others => '0');
                has_exact := true;
                
            elsif is_zero_a = '1' then
                temp_result := effective_sign_b & std_logic_vector(exp_b) & std_logic_vector(mant_b);
                has_exact := true;
                
            elsif is_zero_b = '1' then
                temp_result := sign_a & std_logic_vector(exp_a) & std_logic_vector(mant_a);
                has_exact := true;
                
            else
                if exp_a > exp_b or (exp_a = exp_b and mant_a >= mant_b) then
                    a_larger := '1';
                else
                    a_larger := '0';
                end if;
                
                if exp_a = ZERO_EXP then
                    mant_a_norm := '0' & mant_a; 
                    else
                    mant_a_norm := '1' & mant_a; 
                end if;
                
                if exp_b = ZERO_EXP then
                    mant_b_norm := '0' & mant_b; 
                else
                    mant_b_norm := '1' & mant_b; 
                end if;
                
                mant_a_ext := mant_a_norm & "000";
                mant_b_ext := mant_b_norm & "000";
                
                if a_larger = '1' then
                    exp_diff := to_integer(exp_a) - to_integer(exp_b);
                    exp_result := to_integer(exp_a);
                    mant_a_aligned := mant_a_ext;
                    if exp_diff > 25 then
                        mant_b_aligned := (others => '0');
                        if mant_b_ext /= 0 then
                            bits_lost := true; 
                            end if;
                    else
                        if exp_diff > 0 and mant_b_ext /= 0 then
                            for i in 0 to exp_diff-1 loop
                                if mant_b_ext(i) = '1' then
                                    bits_lost := true;
                                    exit;
                                end if;
                            end loop;
                        end if;
                        mant_b_aligned := shift_right(mant_b_ext, exp_diff);
                    end if;
                else
                    exp_diff := to_integer(exp_b) - to_integer(exp_a);
                    exp_result := to_integer(exp_b);
                    mant_b_aligned := mant_b_ext;
                    if exp_diff > 25 then
                        mant_a_aligned := (others => '0');
                        if mant_a_ext /= 0 then
                            bits_lost := true; 
                        end if;
                    else
                        if exp_diff > 0 and mant_a_ext /= 0 then
                            for i in 0 to exp_diff-1 loop
                                if mant_a_ext(i) = '1' then
                                    bits_lost := true;
                                    exit;
                                end if;
                            end loop;
                        end if;
                        mant_a_aligned := shift_right(mant_a_ext, exp_diff);
                    end if;
                end if;
                
                original_exp_result := exp_result;
                
                if effective_operation = '0' then 
                    mant_result_raw := ('0' & mant_a_aligned) + ('0' & mant_b_aligned);
                    if a_larger = '1' then
                        sign_result := sign_a;
                    else
                        sign_result := effective_sign_b;
                    end if;
                else 
                    if mant_a_aligned >= mant_b_aligned then
                        mant_result_raw := ('0' & mant_a_aligned) - ('0' & mant_b_aligned);
                        sign_result := sign_a;
                    else
                        mant_result_raw := ('0' & mant_b_aligned) - ('0' & mant_a_aligned);
                        sign_result := effective_sign_b;
                    end if;
                end if;
                
                if mant_result_raw = 0 then
                    temp_result := (others => '0');
                    has_exact := true;
                else
                    exp_result_final := exp_result;
                    
                    if mant_result_raw(26) = '1' then
                        if mant_result_raw(0) = '1' then
                            bits_lost := true;
                        end if;
                        mant_result_raw := shift_right(mant_result_raw, 1);
                        exp_result_final := exp_result_final + 1;
                    elsif mant_result_raw(25) = '0' then
                        leading_zeros := 0;
                        for i in 25 downto 0 loop
                            if mant_result_raw(i) = '1' then
                                exit;
                            else
                                leading_zeros := leading_zeros + 1;
                            end if;
                        end loop;
                        
                        if leading_zeros <= 25 then
                            mant_result_raw := shift_left(mant_result_raw, leading_zeros);
                            exp_result_final := exp_result_final - leading_zeros;
                        end if;
                    end if;
                    
                    if exp_result_final >= 511 then
                        would_be_overflow := true;

                    elsif original_exp_result >= 510 and effective_operation = '0' then 
                        would_be_overflow := true;
                    end if;
                    
                    if exp_result_final <= 0 then
                        would_be_underflow := true;

                    elsif original_exp_result <= 2 and effective_operation = '1' then 

                        if leading_zeros > original_exp_result then
                            would_be_underflow := true;
                        end if;
                    end if;

                    if would_be_overflow then
                        temp_result := sign_result & std_logic_vector(INF_EXP) & std_logic_vector(ZERO_MANT);
                        has_overflow := true;
                        has_inexact := true;
                    elsif would_be_underflow then
                        temp_result := sign_result & std_logic_vector(ZERO_EXP) & std_logic_vector(ZERO_MANT);
                        has_underflow := true;
                        has_inexact := true;
                    else
                        mant_result_final := mant_result_raw(24 downto 3); 
                        guard_bits := mant_result_raw(2 downto 0);
                        
                        temp_result := sign_result & std_logic_vector(to_unsigned(exp_result_final, 9)) & std_logic_vector(mant_result_final);
                        
                        if guard_bits = "000" and not bits_lost then
                            has_exact := true;
                        else
                            has_inexact := true;
                        end if;
                    end if;
                end if;
            end if;
            
            data_out_reg <= temp_result;
            
            status_out_reg(3) <= '1' when has_inexact else '0';
            status_out_reg(2) <= '1' when has_underflow else '0';
            status_out_reg(1) <= '1' when has_overflow else '0';
            status_out_reg(0) <= '1' when has_exact else '0';
        end if;
    end process;
    
end Behavioral;
