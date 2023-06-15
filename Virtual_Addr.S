#include "riscv_test.h"
#define Permissions (PTE_V | PTE_U | PTE_R | PTE_W | PTE_X )
#define Permissions1 (PTE_V)
.option norvc  // for compiler to avoid compressed instructions
RVTEST_RV64M
RVTEST_CODE_BEGIN

	j test_start


crash_backward:
	RVTEST_FAIL



.align 12
 enter_supervisor:  
    
		         
	                 la a0, data_store
			  li a1, 42
			  //# Do a store from the VA 
			  sw a1, (a0)
			  //# Do a load from the VA 
			  lw a1, (a0)

			  //# Check the result
			  li a0, 42		



.align 12
 test_start:
                   // PTE Setup for Code Region                                                                            // One to One Mapping
		  la a0, enter_supervisor;       // Physical Address
		  li a1, Permissions;        // R + W + V + U + E  Permissions
		  li a3,0;           // Level-0 (4KB)      
		  la a2, enter_supervisor;        // Virtual Address                         
		  
		  
		  jal page_table_entry_setup



                  // PTE Setup for lw/sw addresses
                 la a0, data_store;       // Physical Address
		  li a1, Permissions;        // R + W + V + U + E  Permissions
		  li a3,0;           // Level-0 (4KB)                                      
		  la a2, data_store;        // Virtual Address  
		  
		  
		  jal page_table_entry_setup


 
		  
		  la a1,enter_supervisor;           // Load Address where to go after Switching to S-Mode
		  csrw mepc,a1;
		  
		  csrw mie, zero
  
		  // Set up the Physical Memory Protection (PMP) configuration
		  li t2, -1  				// Whole physical memory as single region
		  csrw pmpaddr0, t2
		  li t2, 0x8F 				// TOR mode with lock bit on
		  csrw pmpcfg0, t2
		  
		  //## Turn on VM
		        
		  la a1, page_table_1      // Page Table Level-1 Base Address
	          srl a1, a1, 12;
        
		  li a0, (SATP_MODE & ~(SATP_MODE<<1)) * SATP_MODE_SV32// For SV32 Mode Setup
	          or a0, a0, a1
	          csrw satp, a0
	          sfence.vma        // To Flush Local Memory/TLB
		  
		   //# Set up MPRV with MPP=S and SUM=1, so loads and stores use S-mode and S can access U pages
		  li a1, ((MSTATUS_MPP & ~(MSTATUS_MPP<<1)) * PRV_S) | ;
		  csrs mstatus, a1
		  mret 
		  //# Do a store to MY_VA
  

  
  
.align 12
page_table_entry_setup:
			  srl a0, a0, 12               // Physical Address needs to be mapped
			  sll a0, a0, PTE_PPN_SHIFT  // Shift Left for Different Permissions
			  or a0, a0, a1   // Complete PTE with Permissions                                                      // PTE  Setup @ Page table level-0      


			  beqz a3, Page_table_0_level         
                    //  # Level 1 PTE address
Page_table_1_level:
			  la a0, page_table_0;
			  srl a0, a0, 12;
			  sll a0, a0, PTE_PPN_SHIFT;    // Shift 10-bit left for adding permissons                               // PTE  Setup @ Page table level-1                        
			  li a1, Permissions1;          // Valid Permission Just 
                         or a0, a0, a1     // Complete PTE with Permissions
                         
             
                         la a1, page_table_1; // Page Table Level -1 Base Address
                         srli a5,a2,22;     
                         
                         
                         andi a5,a5, 0x3FF;   // a5=VPN[1]
		          li a4,4;     // 4-Bytes Each PTE for indexing
			  mul a5,a5,a4; // VPN[1]*4 for indexing         
			  add a1, a1, a5           //[Base Address + Index]= Page Table-0 Address + Permissions

			 // # Level 1 PTE store
			  sw a0, (a1)
	  
			ret;
  
  


  
  
Page_table_0_level:
		   la a1, page_table_0;   // e.g- 203456
		   srli a5,a2,12;       // VA>>12
		   andi a5,a5, 0x3FF;   // a5=VPN[0]
		   li a4,4;     // 4-Bytes Each PTE for indexing
		   mul a5,a5,a4;        // VPN[0]*4 for indexing     
		   add a1,a1,a5;  // Base Address + Index
		   
		   sw a0, (a1);        // [Base Address + Index]= Phyiscal Address + Permissions
		 j Page_table_1_level
  
  
  
  
crash_forward:
	RVTEST_FAIL

test_end:
	RVTEST_PASS

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
 
.balign 16
ld_addr:
.dword 0xdeadbeefcafebabe
//.dword 0xdeadbeefcafebabe

.align 12
page_table_0: .space 4096 

.align 12
page_table_1: .space 4096 

.align 12
data_store .space 4096      // For Load/Store with and without Permissions


RVTEST_DATA_END
