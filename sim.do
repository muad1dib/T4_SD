if {[file exists work]} {
    vdel -lib work -all
}

vlib work

vcom -2008 fpu_Mod.vhdl
vcom -2008 tb_fpu.vhdl

vsim -gui fpu_tb

add wave -divider "Clock e Reset"
add wave /fpu_tb/clk
add wave /fpu_tb/reset

add wave -divider "Sinais de Controle"
add wave /fpu_tb/operation
add wave -radix binary /fpu_tb/status

add wave -divider "Operandos de Entrada"
add wave -radix hexadecimal /fpu_tb/Op_A
add wave -radix hexadecimal /fpu_tb/Op_B

add wave -divider "Resultado"
add wave -radix hexadecimal /fpu_tb/result

add wave -divider "Status Detalhado"
add wave /fpu_tb/status(3)
add wave /fpu_tb/status(2) 
add wave /fpu_tb/status(1)
add wave /fpu_tb/status(0)

configure wave -namecolwidth 250
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

run 200 us

add wave -divider "Sinais Internos da FPU"
catch {add wave -radix unsigned /fpu_tb/uut/exp_a_int}
catch {add wave -radix unsigned /fpu_tb/uut/exp_b_int}
catch {add wave -radix binary /fpu_tb/uut/sign_res}
catch {add wave -radix hexadecimal /fpu_tb/uut/mant_result}

wave zoom full

write format wave fpu_simulation.wlf

echo "Simulação da FPU concluída!"
echo "Arquivo de ondas salvo como: fpu_simulation.wlf"
