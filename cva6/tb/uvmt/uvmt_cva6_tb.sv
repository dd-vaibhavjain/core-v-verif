// Copyright 2021 Thales DIS Design Services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0


`ifndef __UVMT_CVA6_TB_SV__
`define __UVMT_CVA6_TB_SV__


/**
 * Module encapsulating the CVA6 DUT wrapper, and associated SV interfaces.
 * Also provide UVM environment entry and exit points.
 */
`default_nettype none
module uvmt_cva6_tb;

   import uvm_pkg::*;
   import uvmt_cva6_pkg::*;
   import uvme_cva6_pkg::*;

   // CVA6 config
   localparam ariane_pkg::cva6_cfg_t CVA6Cfg = {
     unsigned'(cva6_config_pkg::CVA6ConfigNrCommitPorts),  // NrCommitPorts
     unsigned'(cva6_config_pkg::CVA6ConfigAxiAddrWidth),   // AxiAddrWidth
     unsigned'(cva6_config_pkg::CVA6ConfigAxiDataWidth),   // AxiDataWidth
     unsigned'(cva6_config_pkg::CVA6ConfigAxiIdWidth),     // AxiIdWidth
     unsigned'(cva6_config_pkg::CVA6ConfigDataUserWidth),  // AxiUserWidth
     bit'(cva6_config_pkg::CVA6ConfigFpuEn),               // FpuEn
     bit'(cva6_config_pkg::CVA6ConfigF16En),               // XF16
     bit'(cva6_config_pkg::CVA6ConfigF16AltEn),            // XF16ALT
     bit'(cva6_config_pkg::CVA6ConfigF8En),                // XF8
     bit'(cva6_config_pkg::CVA6ConfigAExtEn),              // RVA
     bit'(cva6_config_pkg::CVA6ConfigVExtEn),              // RVV
     bit'(cva6_config_pkg::CVA6ConfigCExtEn),              // RVC
     bit'(cva6_config_pkg::CVA6ConfigFVecEn),              // XFVEC
     bit'(cva6_config_pkg::CVA6ConfigCvxifEn),             // CvxifEn
     // Extended
     bit'(0),                                              // RVF
     bit'(0),                                              // RVD
     bit'(0),                                              // FpPresent
     riscv::XLEN'(0),                                      // IsaCode
     bit'(0),                                              // NSX
     unsigned'(0),                                         // FLen
     bit'(0),                                              // RVFVec
     bit'(0),                                              // XF16Vec
     bit'(0),                                              // XF16ALTVec
     bit'(0),                                              // XF8Vec
     unsigned'(0),                                         // NR_RGPR_PORTS
     unsigned'(0),                                         // NrWbPorts
     bit'(0)                                               // EnableAccelerator
   };
   localparam bit IsRVFI = bit'(cva6_config_pkg::CVA6ConfigRvfiTrace);
   localparam type rvfi_instr_t = struct packed {
     logic [ariane_pkg::NRET-1:0]                  valid;
     logic [ariane_pkg::NRET*64-1:0]               order;
     logic [ariane_pkg::NRET*ariane_pkg::ILEN-1:0] insn;
     logic [ariane_pkg::NRET-1:0]                  trap;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      cause;
     logic [ariane_pkg::NRET-1:0]                  halt;
     logic [ariane_pkg::NRET-1:0]                  intr;
     logic [ariane_pkg::NRET*2-1:0]                mode;
     logic [ariane_pkg::NRET*2-1:0]                ixl;
     logic [ariane_pkg::NRET*5-1:0]                rs1_addr;
     logic [ariane_pkg::NRET*5-1:0]                rs2_addr;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      rs1_rdata;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      rs2_rdata;
     logic [ariane_pkg::NRET*5-1:0]                rd_addr;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      rd_wdata;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      pc_rdata;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      pc_wdata;
     logic [ariane_pkg::NRET*riscv::VLEN-1:0]      mem_addr;
     logic [ariane_pkg::NRET*riscv::PLEN-1:0]      mem_paddr;
     logic [ariane_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_rmask;
     logic [ariane_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_wmask;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      mem_rdata;
     logic [ariane_pkg::NRET*riscv::XLEN-1:0]      mem_wdata;
   };

   localparam AXI_USER_EN       = ariane_pkg::AXI_USER_EN;
   localparam NUM_WORDS         = 2**24;

   // ENV (testbench) parameters
   parameter int ENV_PARAM_INSTR_ADDR_WIDTH  = 32;
   parameter int ENV_PARAM_INSTR_DATA_WIDTH  = 32;
   parameter int ENV_PARAM_RAM_ADDR_WIDTH    = 22;

   // Agent interfaces
   uvma_clknrst_if              clknrst_if(); // clock and resets from the clknrst agent
   uvma_cvxif_intf              cvxif_if(
                                         .clk(clknrst_if.clk),
                                         .reset_n(clknrst_if.reset_n)
                                        ); // cvxif from the cvxif agent
   uvma_axi_intf                axi_if(
                                         .clk(clknrst_if.clk),
                                         .rst_n(clknrst_if.reset_n)
                                      );
   uvmt_axi_switch_intf         axi_switch_vif();
   uvme_cva6_core_cntrl_if      core_cntrl_if();
   uvma_rvfi_instr_if #(
     uvme_cva6_pkg::ILEN,
     uvme_cva6_pkg::XLEN
   ) rvfi_instr_if [uvme_cva6_pkg::RVFI_NRET-1:0] ();

    uvma_rvfi_csr_if#(uvme_cva6_pkg::XLEN)       rvfi_csr_if [uvme_cva6_pkg::RVFI_NRET-1:0]();

   //bind assertion module for cvxif interface
   bind uvmt_cva6_dut_wrap
      uvma_cvxif_assert          cvxif_assert(.cvxif_assert(cvxif_if),
                                              .clk(clknrst_if.clk),
                                              .reset_n(clknrst_if.reset_n)
                                             );
   //bind assertion module for axi interface
   bind uvmt_cva6_dut_wrap
      uvmt_axi_assert            axi_assert(.axi_assert(axi_if.passive),
                                            .clk(clknrst_if.clk),
                                            .rst_n(clknrst_if.reset_n)
                                           );
   // DUT Wrapper Interfaces
   uvmt_rvfi_if #(
     // RVFI
     .rvfi_instr_t      ( rvfi_instr_t ),
     .CVA6Cfg           ( CVA6Cfg      )
   ) rvfi_if(
                                                 .rvfi_o(),
                                                 .tb_exit_o()
                                                 ); // Status information generated by the Virtual Peripherals in the DUT WRAPPER memory.

  /**
   * DUT WRAPPER instance
   */

   uvmt_cva6_dut_wrap #(
     .CVA6Cfg           ( CVA6Cfg       ),
     .IsRVFI            ( IsRVFI        ),
     .rvfi_instr_t      ( rvfi_instr_t  ),
     //
     .AXI_USER_EN       (AXI_USER_EN),
     .NUM_WORDS         (NUM_WORDS)
   ) cva6_dut_wrap (
                    .clknrst_if(clknrst_if),
                    .cvxif_if  (cvxif_if),
                    .axi_if    (axi_if),
                    .axi_switch_vif    (axi_switch_vif),
                    .core_cntrl_if(core_cntrl_if),
                    .tb_exit_o(rvfi_if.tb_exit_o),
                    .rvfi_o(rvfi_if.rvfi_o)
                    );

   for (genvar i = 0; i < uvme_cva6_pkg::RVFI_NRET; i++) begin
      assign  rvfi_instr_if[i].clk            = clknrst_if.clk;
      assign  rvfi_instr_if[i].reset_n        = clknrst_if.reset_n;
      assign  rvfi_instr_if[i].rvfi_valid     = rvfi_if.rvfi_o[i].valid;
      assign  rvfi_instr_if[i].rvfi_order     = rvfi_if.rvfi_o[i].order;
      assign  rvfi_instr_if[i].rvfi_insn      = rvfi_if.rvfi_o[i].insn;
      assign  rvfi_instr_if[i].rvfi_trap      = rvfi_if.rvfi_o[i].trap;
      assign  rvfi_instr_if[i].rvfi_halt      = rvfi_if.rvfi_o[i].halt;
      assign  rvfi_instr_if[i].rvfi_intr      = rvfi_if.rvfi_o[i].intr;
      assign  rvfi_instr_if[i].rvfi_mode      = rvfi_if.rvfi_o[i].mode;
      assign  rvfi_instr_if[i].rvfi_ixl       = rvfi_if.rvfi_o[i].ixl;
      assign  rvfi_instr_if[i].rvfi_pc_rdata  = rvfi_if.rvfi_o[i].pc_rdata;
      assign  rvfi_instr_if[i].rvfi_pc_wdata  = rvfi_if.rvfi_o[i].pc_wdata;
      assign  rvfi_instr_if[i].rvfi_rs1_addr  = rvfi_if.rvfi_o[i].rs1_addr;
      assign  rvfi_instr_if[i].rvfi_rs1_rdata = rvfi_if.rvfi_o[i].rs1_rdata;
      assign  rvfi_instr_if[i].rvfi_rs2_addr  = rvfi_if.rvfi_o[i].rs2_addr;
      assign  rvfi_instr_if[i].rvfi_rs2_rdata = rvfi_if.rvfi_o[i].rs2_rdata;
      assign  rvfi_instr_if[i].rvfi_rd1_addr  = rvfi_if.rvfi_o[i].rd_addr;
      assign  rvfi_instr_if[i].rvfi_rd1_wdata = rvfi_if.rvfi_o[i].rd_wdata;
      assign  rvfi_instr_if[i].rvfi_mem_addr  = rvfi_if.rvfi_o[i].mem_addr;
      assign  rvfi_instr_if[i].rvfi_mem_rdata = rvfi_if.rvfi_o[i].mem_rdata;
      assign  rvfi_instr_if[i].rvfi_mem_rmask = rvfi_if.rvfi_o[i].mem_rmask;
      assign  rvfi_instr_if[i].rvfi_mem_wdata = rvfi_if.rvfi_o[i].mem_wdata;
      assign  rvfi_instr_if[i].rvfi_mem_wmask = rvfi_if.rvfi_o[i].mem_wmask;
   end


   for (genvar i = 0; i < uvme_cva6_pkg::RVFI_NRET; i++) begin
      initial  begin
         uvm_config_db#(virtual uvma_rvfi_instr_if )::set(null,"*", $sformatf("instr_vif%0d", i), rvfi_instr_if[i]);

         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_marchid_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mcountinhibit_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mstatus_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_ustatus_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mstatush_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_misa_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mtvec_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_utvec_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mtval_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_utval_vif%0d", i),       rvfi_csr_if[i]);
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mvendorid_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mscratch_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mepc_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_uepc_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mcause_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_ucause_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mip_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_uip_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mie_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_uie_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhartid_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mimpid_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_minstret_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_minstreth_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mcontext_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mcycle_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mcycleh_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_dcsr_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_dpc_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_dscratch0_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_dscratch1_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_uscratch_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_scontext_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_tselect_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_tdata1_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_tdata2_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_tdata3_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_tinfo_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_tcontrol_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent3_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent4_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent5_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent6_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent7_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent8_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent9_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent10_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent11_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent12_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent13_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent14_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent15_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent16_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent17_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent18_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent19_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent20_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent21_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent22_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent23_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent24_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent25_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent26_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent27_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent28_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent28_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent29_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent30_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmevent31_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter3_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter4_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter5_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter6_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter7_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter8_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter9_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter10_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter11_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter12_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter13_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter14_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter15_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter16_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter17_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter18_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter19_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter20_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter21_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter22_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter23_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter24_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter25_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter26_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter27_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter28_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter29_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter30_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter31_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter3h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter4h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter5h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter6h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter7h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter8h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter9h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter10h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter11h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter12h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter13h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter14h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter15h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter16h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter17h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter18h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter19h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter20h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter21h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter22h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter23h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter24h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter25h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter26h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter27h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter28h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter29h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter30h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mhpmcounter31h_vif%0d", i),       .value(rvfi_csr_if[i]));
         uvm_config_db#(virtual uvma_rvfi_csr_if )::set(null,"*", $sformatf("csr_mconfigptr_vif%0d", i),       .value(rvfi_csr_if[i]));
    end
   end
   /**
    * Test bench entry point.
    */
   initial begin : test_bench_entry_point

     // Specify time format for simulation (units_number, precision_number, suffix_string, minimum_field_width)
     $timeformat(-9, 3, " ns", 8);

     // Add interfaces handles to uvm_config_db
     uvm_config_db#(virtual uvma_clknrst_if )::set(.cntxt(null), .inst_name("*.env.clknrst_agent"), .field_name("vif"),       .value(clknrst_if));
     uvm_config_db#(virtual uvma_cvxif_intf )::set(.cntxt(null), .inst_name("*.env.cvxif_agent"),   .field_name("vif"),       .value(cvxif_if)  );
     uvm_config_db#(virtual uvma_axi_intf   )::set(.cntxt(null), .inst_name("*"),                   .field_name("axi_vif"),    .value(axi_if));
     uvm_config_db#(virtual uvmt_axi_switch_intf  )::set(.cntxt(null), .inst_name("*.env"),             .field_name("axi_switch_vif"),   .value(axi_switch_vif));
     uvm_config_db#(virtual uvmt_rvfi_if    )::set(.cntxt(null), .inst_name("*"),                   .field_name("rvfi_vif"),  .value(rvfi_if));
     uvm_config_db#(virtual uvme_cva6_core_cntrl_if)::set(.cntxt(null), .inst_name("*"), .field_name("core_cntrl_vif"),  .value(core_cntrl_if));

     // DUT and ENV parameters
     uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("ENV_PARAM_INSTR_ADDR_WIDTH"),  .value(ENV_PARAM_INSTR_ADDR_WIDTH) );
     uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("ENV_PARAM_INSTR_DATA_WIDTH"),  .value(ENV_PARAM_INSTR_DATA_WIDTH) );
     uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("ENV_PARAM_RAM_ADDR_WIDTH"),    .value(ENV_PARAM_RAM_ADDR_WIDTH)   );

     // Run test
     uvm_top.enable_print_topology = 0; // ENV coders enable this as a debug aid
     uvm_top.finish_on_completion  = 1;
     uvm_top.run_test();
   end : test_bench_entry_point

   assign core_cntrl_if.clk = clknrst_if.clk;

   /**
    * End-of-test summary printout.
    */
   final begin: end_of_test
      string             summary_string;
      uvm_report_server  rs;
      int                err_count;
      int                warning_count;
      int                fatal_count;
      static bit         sim_finished = 0;
      static int         test_exit_code = 0;

      static string  red   = "\033[31m\033[1m";
      static string  green = "\033[32m\033[1m";
      static string  reset = "\033[0m";

      rs            = uvm_top.get_report_server();
      err_count     = rs.get_severity_count(UVM_ERROR);
      warning_count = rs.get_severity_count(UVM_WARNING);
      fatal_count   = rs.get_severity_count(UVM_FATAL);

      void'(uvm_config_db#(bit)::get(null, "", "sim_finished", sim_finished));
      void'(uvm_config_db#(int)::get(null, "", "test_exit_code", test_exit_code));

      $display("\n%m: *** Test Summary ***\n");

      if (sim_finished && (test_exit_code == 0) && (err_count == 0) && (fatal_count == 0)) begin
         $display("    PPPPPPP    AAAAAA    SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    PP    PP  AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP    PP  AA    AA  SS        SS        EE        DD    DD    ");
         $display("    PPPPPPP   AAAAAAAA   SSSSSS    SSSSSS   EEEEE     DD    DD    ");
         $display("    PP        AA    AA        SS        SS  EE        DD    DD    ");
         $display("    PP        AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP        AA    AA   SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    ----------------------------------------------------------");
         if (warning_count == 0) begin
           $display("                        SIMULATION PASSED                     ");
         end
         else begin
           $display("                 SIMULATION PASSED with WARNINGS              ");
         end
         $display("                 test exit code = %0d (0x%h)", test_exit_code, test_exit_code);
         $display("    ----------------------------------------------------------");
      end
      else begin
         $display("    FFFFFFFF   AAAAAA   IIIIII  LL        EEEEEEEE  DDDDDDD       ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FFFFF     AAAAAAAA    II    LL        EEEEE     DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA  IIIIII  LLLLLLLL  EEEEEEEE  DDDDDDD       ");
         $display("    ----------------------------------------------------------");
         if (sim_finished == 0) begin
            $display("                   SIMULATION FAILED - ABORTED              ");
         end
         else begin
            $display("                       SIMULATION FAILED                    ");
            $display("                 test exit code = %0d (0x%h)", test_exit_code, test_exit_code);
         end
         $display("    ----------------------------------------------------------");
      end
   end

endmodule : uvmt_cva6_tb
`default_nettype wire

`endif // __UVMT_CVA6_TB_SV__
