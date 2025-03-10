// ----------------------------------------------------------------------------
//Copyright 2023 CEA*
//*Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//[END OF HEADER]
// ----------------------------------------------------------------------------

package dut_env_pkg;
  import uvm_pkg::*;
  import watchdog_pkg::*;
  import clock_driver_pkg::*;
  import reset_driver_pkg::*;
  import bp_driver_pkg::*;
  import uvma_axi_pkg::*;
  typedef enum {
      NO_BP,
      HEAVY_BP,
      OCCASSIONAL_BP
  } bp_type_t;
  `include "uvm_macros.svh"
  `include "bp_virtual_sequence.svh"
  `include "dut_cfg_c.svh"
  `include "mem_protocol_checker.sv"
  `include "dut_env_axi_ohg.sv"
endpackage: dut_env_pkg
