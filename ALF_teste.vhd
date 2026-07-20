library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- janela 10x10 e pixels de 16-bits
package alf_types is
    type pixel_window is array (0 to 9, 0 to 9) of unsigned(15 downto 0);
end package;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.alf_types.all;

entity alf_teste is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        pixels_in   : in  pixel_window; 
        vb_mode     : in  STD_LOGIC_VECTOR(1 downto 0); -- 00=Normal, 01=VB_Acima, 10=VB_Abaixo
        class_out   : out STD_LOGIC_VECTOR(4 downto 0) 
    );
end entity alf_teste;

architecture Pipelined_Architecture of alf_teste is
  
    signal gh_reg, gv_reg, gd1_reg, gd2_reg : unsigned(21 downto 0);
    signal activity_reg                     : unsigned(2 downto 0);
    signal d_dir_reg                        : unsigned(2 downto 0);
    signal act_pipe                         : unsigned(2 downto 0);
begin
    
    -- ESTÁGIO 1: CÁLCULO DOS GRADIENTES E ATIVIDADE (COM PADDING PARA VB)
   
    process(clk, reset)
        variable sum_h, sum_v, sum_d1, sum_d2 : unsigned(21 downto 0);
        variable val_center                   : unsigned(16 downto 0);
        variable n_a, n_b, n_sum              : unsigned(16 downto 0);
        variable diff                         : unsigned(16 downto 0);
        variable act_sum                      : unsigned(22 downto 0);
        
        -- Variáveis para controle de linha vizinha 
        variable r_n_a : integer range 0 to 9;
        variable r_n_b : integer range 0 to 9;
    begin
        if reset = '1' then
            gh_reg       <= (others => '0');
            gv_reg       <= (others => '0');
            gd1_reg      <= (others => '0');
            gd2_reg      <= (others => '0');
            activity_reg <= (others => '0');
        elsif rising_edge(clk) then
            sum_h  := (others => '0');
            sum_v  := (others => '0');
            sum_d1 := (others => '0');
            sum_d2 := (others => '0');
            
            for k in 1 to 8 loop
                -- LÓGICA VIRTUAL BOUNDARY: Pula linhas cruzadas
                if not ((vb_mode = "01" and k >= 7) or (vb_mode = "10" and k <= 2)) then
                    
                    r_n_a := k - 1;
                    r_n_b := k + 1;
                    
                    -- PADDING VTM: Clampa a linha de leitura na fronteira adjacente
                    if vb_mode = "01" and k = 6 then
                        r_n_b := 6;
                    end if;
                    if vb_mode = "10" and k = 3 then
                        r_n_a := 3;
                    end if;

                    for l in 1 to 8 loop
                        if (k mod 2) = (l mod 2) then
                            val_center := resize(pixels_in(k, l), 17) + resize(pixels_in(k, l), 17);
                            
                            -- Horizontal (Não sofre padding vertical)
                            n_a := resize(pixels_in(k, l-1), 17);
                            n_b := resize(pixels_in(k, l+1), 17);
                            n_sum := n_a + n_b;
                            if val_center > n_sum then diff := val_center - n_sum; else diff := n_sum - val_center; end if;
                            sum_h := sum_h + resize(diff, 22);
                            
                            -- Vertical (Usa r_n_a e r_n_b com padding)
                            n_a := resize(pixels_in(r_n_a, l), 17);
                            n_b := resize(pixels_in(r_n_b, l), 17);
                            n_sum := n_a + n_b;
                            if val_center > n_sum then diff := val_center - n_sum; else diff := n_sum - val_center; end if;
                            sum_v := sum_v + resize(diff, 22);
                            
                            -- Diagonal 1 (Usa r_n_a e r_n_b com padding)
                            n_a := resize(pixels_in(r_n_a, l-1), 17);
                            n_b := resize(pixels_in(r_n_b, l+1), 17);
                            n_sum := n_a + n_b;
                            if val_center > n_sum then diff := val_center - n_sum; else diff := n_sum - val_center; end if;
                            sum_d1 := sum_d1 + resize(diff, 22);
                            
                            -- Diagonal 2 (Usa r_n_a e r_n_b com padding)
                            n_a := resize(pixels_in(r_n_a, l+1), 17);
                            n_b := resize(pixels_in(r_n_b, l-1), 17);
                            n_sum := n_a + n_b;
                            if val_center > n_sum then diff := val_center - n_sum; else diff := n_sum - val_center; end if;
                            sum_d2 := sum_d2 + resize(diff, 22);
                        end if;
                    end loop;
                end if;
            end loop;
            
            gh_reg  <= sum_h;
            gv_reg  <= sum_v;
            gd1_reg <= sum_d1;
            gd2_reg <= sum_d2;
            
            act_sum := resize(sum_h, 23) + resize(sum_v, 23);
            
            -- LÓGICA VIRTUAL BOUNDARY
            if vb_mode = "00" then
                if act_sum < 256 then        activity_reg <= "000"; 
                elsif act_sum < 512 then     activity_reg <= "001"; 
                elsif act_sum < 1792 then    activity_reg <= "010"; 
                elsif act_sum < 3840 then    activity_reg <= "011"; 
                else                         activity_reg <= "100"; 
                end if;
            else
                if act_sum < 171 then        activity_reg <= "000"; 
                elsif act_sum < 342 then     activity_reg <= "001"; 
                elsif act_sum < 1195 then    activity_reg <= "010"; 
                elsif act_sum < 2560 then    activity_reg <= "011"; 
                else                         activity_reg <= "100"; 
                end if;
            end if;
        end if;
    end process;


    -- ESTÁGIO 2: ÁRVORE DE DECISÃO LÓGICA (D)

    process(clk, reset)
        variable h_max, h_min : unsigned(21 downto 0);
        variable d_max, d_min : unsigned(21 downto 0);
        variable dir_hv, dir_d: unsigned(1 downto 0);
        variable hvd1, hvd0   : unsigned(21 downto 0);
        variable main_dir     : unsigned(1 downto 0);
        variable strength     : unsigned(2 downto 0);
        variable mult_d       : unsigned(43 downto 0);
        variable mult_hv      : unsigned(43 downto 0);
    begin
        if reset = '1' then
            d_dir_reg <= (others => '0');
            act_pipe  <= (others => '0');
        elsif rising_edge(clk) then
            act_pipe <= activity_reg;
            
            if gv_reg > gh_reg then h_max := gv_reg; h_min := gh_reg; dir_hv := "01"; else h_max := gh_reg; h_min := gv_reg; dir_hv := "11"; end if;
            if gd1_reg > gd2_reg then d_max := gd1_reg; d_min := gd2_reg; dir_d := "00"; else d_max := gd2_reg; d_min := gd1_reg; dir_d := "10"; end if;
            
            mult_d  := d_max * h_min;
            mult_hv := h_max * d_min;
            
            if mult_d > mult_hv then
                hvd1 := d_max; hvd0 := d_min; main_dir := dir_d;
            else
                hvd1 := h_max; hvd0 := h_min; main_dir := dir_hv;
            end if;
            
            strength := "000";
            if hvd1 > (hvd0 + hvd0) then
                strength := "001";
                if (resize(hvd1, 26) * 2) > (resize(hvd0, 26) * 9) then 
                    strength := "010"; 
                end if;
            end if;
            
            if strength = "000" then 
                d_dir_reg <= "000";
            else 
                if main_dir(0) = '1' then
                    d_dir_reg <= "010" + strength; 
                else
                    d_dir_reg <= "000" + strength;
                end if;
            end if;
        end if;
    end process;


    -- ESTÁGIO 3: EQUAÇÃO FINAL C = 5D + A

    process(clk, reset)
        variable val_d : unsigned(2 downto 0);
    begin
        if reset = '1' then
            class_out <= (others => '0');
        elsif rising_edge(clk) then
            val_d := d_dir_reg;
            class_out <= std_logic_vector(resize(val_d * 5, 5) + resize(act_pipe, 5));
        end if;
    end process;

end architecture Pipelined_Architecture;