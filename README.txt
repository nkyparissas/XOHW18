Team number: xohw18-220
Project name: A Parallel Framework for Simulating Cellular Automata on FPGA Logic
Date: June 2018
Version of uploaded archive: 1

University name: Technical University of Crete, School of ECE
Supervisor name: Apostolos Dollas
Supervisor e-mail: dollas@ece.tuc.gr
Participant: Nikolaos Kyparissas
Email: nkyparissas@isc.tuc.gr

Board used: Nexys 4 DDR
Vivado Version: 2018.1
Brief description of project: In this project, we propose a customizable 
parallel framework on FPGA, which can be used to efficiently simulate weighted, 
large-neighborhood totalistic and outer-totalistic 2D CA.

Description of archive (explain directory structure, documents and source files):
- doc/ : The project's report.
- hw/ : The bitstreams of the 2 showcased examples.
- ip/ : All the xci files needed to generate the Xilinx IP cores used in our project.
- src/constraints/ : 2 xdc files containing the IO netlist and the timing constraints 
of the project.
- src/vhdl/ : The VHDL source files of the project. Choose either 
one CA_ENGINE.vhd file out of the 2 from the appropriate directories 
"src/vhdl/Artificial\ Physics/" and "src/vhdl/Hodgepodge"
- sw/ : contains the matlab scripts and executables required to initialize the system.
Use the instructions below to use the software as required. 

Instructions to build and test the project:
Step 1: 
Connect Digilent's Nexys 4 Board to a tv or monitor via VGA. 
The tv or monitor must support 1080p mode (1920x1080@60Hz).

Step 2:
Connect Digilent's Nexys 4 Board to a Computer via USB.

Step 3:
Load either Artificial_Physics.bit or Hodgepodge.bit via Vivado's Hardware Manager.

Step 4: 
Run the appropriate uart.exe: 4-bit for Artificial_Physics and 8-bit for Hodgepodge.
Follow the instructions to load random.txt from the corresponsing folder.

If LED1 is ON, the system initialization via UART 
has been successful. If not, check that the correct
versions of uart.exe and random.txt have been used.

The initialization has been successful, the simulation is running. 
You can use the board's "up" and "down" push-buttons to adjust the speed.  

Link to YouTube Video(s): https://youtu.be/HYWyuwxIZ94
