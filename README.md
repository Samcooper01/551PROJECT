# MazeRunner

Check out the project demo [here](https://drive.google.com/file/d/13gR39I4FwrdP1VyeVpJc-fJw4XRrLq_s/view?usp=sharing)

## Project Overview
MazeRunner is a project that involves designing, simulating, and debugging a maze-solving robot using various sensors and actuators. The goal is to navigate through a maze using the MazeRunner module and implement it on an FPGA.

## Design Description
- **Example Design**: Maze-solving robot.
- **Components**:
  - IR Sensors
  - Hall Sensor
  - Gyro Sensor
  - Motors
  - Various digital blocks (UART wrapper, PID controller, etc.)

## Part 1: Custom Logic Design
### Part 1a: Design and Simulation
- Design custom logic in Verilog/SystemVerilog.
- Write code for various sensors and actuators.
- Simulate the design using the provided testbench and verify behavior.

### Part 1b: Timing Constraints
- Modify the clock frequency and ensure the design meets the timing requirements.
- Synthesize the design and check the timing constraints using the Timing Analyzer.

## Part 2: On-Board Testing
### Part 2a: Integration and Testing
- Integrate the custom logic with the provided modules.
- Test the design on the DE0 FPGA board using the provided testbench and test suite.
- Use LEDs and 7-segment displays to track and display the states and outputs.

### Part 2b: Code Coverage and Verification
- Run code coverage on the test suite and use the results to improve the test suite.
- Ensure the correct implementation of the MazeRunner module using SignalTap and other verification tools.
