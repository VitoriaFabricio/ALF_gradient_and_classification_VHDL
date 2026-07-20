library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.alf_types.all;

entity alf_testebench is
end entity alf_testebench;

architecture sim of alf_testebench is

    component alf_teste is
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            pixels_in   : in  pixel_window; 
            vb_mode     : in  STD_LOGIC_VECTOR(1 downto 0);
            class_out   : out STD_LOGIC_VECTOR(4 downto 0) 
        );
    end component;

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '1';
    signal pixels_in   : pixel_window := (others => (others => (others => '0')));
    signal vb_mode_sig : std_logic_vector(1 downto 0) := "00";
    signal class_out   : std_logic_vector(4 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    DUT: alf_teste
        port map (
            clk       => clk,
            reset     => reset,
            pixels_in => pixels_in,
            vb_mode   => vb_mode_sig,
            class_out => class_out
        );

    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stimulus: process
        file csv_file      : text open read_mode is "vetores_alf.csv";
        variable row_line  : line;
        variable pixel_val : integer;
        variable comma     : character;
        variable exp_val   : integer;
        variable vb_val    : integer;
        variable block_cnt : integer := 0;
        variable error_cnt : integer := 0;
        variable hw_class  : integer;
    begin
        wait until falling_edge(clk);
        reset <= '1';
        wait for CLK_PERIOD * 2;
        reset <= '0';

        while not endfile(csv_file) loop
            readline(csv_file, row_line);
            if row_line'length = 0 then
                next;
            end if;

            -- Lê os 100 pixels (janela 10x10)
            for row in 0 to 9 loop
                for col in 0 to 9 loop
                    read(row_line, pixel_val);
                    pixels_in(row, col) <= to_unsigned(pixel_val, 16);
                    read(row_line, comma); 
                end loop;
            end loop;

            -- Lê a classe esperada
            read(row_line, exp_val);
            
            -- Lê a vírgula e o indicador de Virtual Boundary (0, 1 ou 2)
            read(row_line, comma);
            read(row_line, vb_val);
            
            vb_mode_sig <= std_logic_vector(to_unsigned(vb_val, 2));

            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait for 1 ns;

            hw_class := to_integer(unsigned(class_out));

            if hw_class /= exp_val then
                report "ERRO no Bloco " & integer'image(block_cnt) & 
                       ". Esperava: " & integer'image(exp_val) & 
                       ", Hardware DEU: " & integer'image(hw_class) severity warning;
                error_cnt := error_cnt + 1;
            end if;

            block_cnt := block_cnt + 1;
            wait until falling_edge(clk);
        end loop;

        report "SIMULACAO CONCLUIDA! Blocos Testados: " & integer'image(block_cnt) & " | Erros: " & integer'image(error_cnt) severity note;
       

        assert false report "Fim do Testbench." severity failure;
        wait;
    end process;

end architecture sim;