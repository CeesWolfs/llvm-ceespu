//===-- CeespuInstrInfo.td - Target Description for Ceespu Target ---------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file describes the Ceespu instructions in TableGen format.
//
//===----------------------------------------------------------------------===//

include "CeespuInstrFormats.td"

// Instruction Operands and Patterns

// These are target-independent nodes, but have target-specific formats.
def SDT_CeespuCallSeqStart : SDCallSeqStart<[SDTCisVT<0, iPTR>]>;
def SDT_CeespuCallSeqEnd   : SDCallSeqEnd<[SDTCisVT<0, iPTR>, SDTCisVT<1, iPTR>]>;
def SDT_CeespuCall         : SDTypeProfile<0, -1, [SDTCisVT<0, iPTR>]>;
def SDT_CeespuSetFlag      : SDTypeProfile<0, 3, [SDTCisSameAs<0, 1>]>;
def SDT_CeespuSelectCC     : SDTypeProfile<1, 5, [SDTCisSameAs<1, 2>,
                                               SDTCisSameAs<0, 4>,
                                               SDTCisSameAs<4, 5>]>;
def SDT_CeespuBrCC         : SDTypeProfile<0, 4, [SDTCisSameAs<0, 1>,
                                               SDTCisVT<3, OtherVT>]>;
def SDT_CeespuWrapper      : SDTypeProfile<1, 1, [SDTCisSameAs<0, 1>,
                                               SDTCisPtrTy<0>]>;

def Ceespucall         : SDNode<"CeespuISD::CALL", SDT_CeespuCall,
                             [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue,
                              SDNPVariadic]>;
def Ceespuretflag      : SDNode<"CeespuISD::RET_FLAG", SDTNone,
                             [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;
def Ceespucallseq_start: SDNode<"ISD::CALLSEQ_START", SDT_CeespuCallSeqStart,
                             [SDNPHasChain, SDNPOutGlue]>;
def Ceespucallseq_end  : SDNode<"ISD::CALLSEQ_END",   SDT_CeespuCallSeqEnd,
                             [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

def Ceespuselectcc     : SDNode<"CeespuISD::SELECT_CC", SDT_CeespuSelectCC, [SDNPInGlue]>;
def CeespuWrapper      : SDNode<"CeespuISD::Wrapper", SDT_CeespuWrapper>;

// Extract bits 0-15 (low-end) of an immediate value.
def LO16 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((uint64_t)N->getZExtValue() & 0xffff,
                                   SDLoc(N), MVT::i32);
}]>;

// Extract bits 16-31 (high-end) of an immediate value.
// Transformation function: shift the immediate value down into the low bits.
def HI16 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((uint64_t)N->getZExtValue() >> 16, SDLoc(N),
                                   MVT::i32);
}]>;


def brtarget : Operand<OtherVT>;

def calltarget : Operand<i16>;

def u32imm   : Operand<i32> {
  let PrintMethod = "printImm32Operand";
}

def i32immSExt16 : PatLeaf<(imm), [{ return isInt<16>(N->getSExtValue()); }]>;


def u5imm : Operand<i32>, ImmLeaf<i32, [{return isUInt<5>(Imm);}]> {
  let DecoderMethod = "decodeUImmOperand<5>";
}

// Addressing modes.
def ADDR : ComplexPattern<i32, 2, "SelectAddr", [], []>;
def FIri : ComplexPattern<i32, 2, "SelectFIAddr", [add, or], []>;

// Address operands
def MEMri : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let EncoderMethod = "getMemoryOpValue";
  let MIOperandInfo = (ops GPR, i16imm);
}

// jump instructions
class BRANCH_COND<CeespuOpcode opc, string opcstr, PatFrag Cond>
    : CeespuB1<opc, (outs), (ins GPR:$ra, GPR:$rb, brtarget:$BrDst),
              opcstr, "$ra, $rb, $BrDst",
              [(brcond (i32 (Cond GPR:$ra, GPR:$rb)), bb:$BrDst)]> {
}

class CALL
    : CeespuB2<OPC_JMP, (outs), (ins calltarget:$imm),
              "call", "$imm",
              []> {
  let Inst{0} = 1;
}

class CALLR
    : CeespuA2<OPC_JMP, (outs), (ins GPR:$ra),
              "callr", "$ra",
              [(Ceespucall GPR:$ra)]> {
  let Inst{1-0} = 0b11;
}

class BRANCHR
    : CeespuA2<OPC_JMP, (outs), (ins GPR:$ra),
              "bx", "$ra",
              [(brind GPR:$ra)]> {
  let Inst{1} = 1;
}

let isBranch = 1, isBarrier = 1, hasDelaySlot = 0, isTerminator = 1, isIndirectBranch = 1 in {
  def BX : BRANCHR;
}

class RET : InstCeespu<OPC_JMP, (outs), (ins), "bx", "clr", [(Ceespuretflag)]> {
  let Inst{1} = 1;
}

let isReturn = 1, isTerminator = 1, hasDelaySlot=0, isBarrier = 1, Uses = [LR], 
    isNotDuplicable = 1 in {
  def RET : RET;
}

let isBranch = 1, isTerminator= 1, hasDelaySlot=0 in {
// branch instructions
def BEQ  : BRANCH_COND<OPC_BEQ,  "beq",  seteq>;
def BGU  : BRANCH_COND<OPC_BGU,  "bgu",  setugt>;
def BGEU : BRANCH_COND<OPC_BGEU, "bgeu", setuge>;
def BNE  : BRANCH_COND<OPC_BNE,  "bne",  setne>;
def BGT  : BRANCH_COND<OPC_BG,   "bg",   setgt>;
def BGE  : BRANCH_COND<OPC_BGE,  "bge",  setge>;
}

def : Pat<(brcond (i32 (setlt GPR:$ra, GPR:$rb)), bb:$BrDst),  (BGE GPR:$rb, GPR:$ra, bb:$BrDst)>;
def : Pat<(brcond (i32 (setult GPR:$ra, GPR:$rb)), bb:$BrDst), (BGEU GPR:$rb, GPR:$ra, bb:$BrDst)>;
def : Pat<(brcond (i32 (setle GPR:$ra, GPR:$rb)), bb:$BrDst),  (BGT GPR:$rb, GPR:$ra, bb:$BrDst)>;
def : Pat<(brcond (i32 (setule GPR:$ra, GPR:$rb)), bb:$BrDst), (BGU GPR:$rb, GPR:$ra, bb:$BrDst)>;

// An extra pattern is needed for a brcond without a setcc (i.e. where the
// condition was calculated elsewhere).
def : Pat<(brcond GPR:$cond, bb:$BrDst), (BNE GPR:$cond, R0, bb:$BrDst)>;

// Jump always
let isBranch = 1, isTerminator = 1, hasDelaySlot=0, isBarrier = 1 in {
  def JMP : CeespuB2<OPC_JMP, (outs), (ins brtarget:$BrDst), "b", "$BrDst" , [(br bb:$BrDst)]>;
}


// Jump and link
let isCall=1, hasDelaySlot=0, Defs = [FP, LR, R20, R21, R22, R23, R24, R25, R13, R14, R15, R26, R27, R28, R29, R30, R31] in {
  def JAL  : CALL;
  def JALR : CALLR;
}

// ALU instructions
class ALU_RI<CeespuOpcode opc, string opcstr, SDNode OpNode>
    : CeespuB0<opc, (outs GPR:$rd), (ins GPR:$ra, i32imm:$imm),
              opcstr, "$rd, $ra, $imm",
              [(set GPR:$rd, (OpNode GPR:$ra, i32immSExt16:$imm))]> {
}

// Extended immidiate ALU instructions
class ALU_RI_EXT<CeespuOpcode opc, string opcstr, SDNode OpNode>
    : Pseudo<(outs GPR:$rd), (ins GPR:$ra, i32imm:$imm), "opcstr", "$rd, $ra, $imm",
              [(set GPR:$rd, (OpNode GPR:$ra, imm:$imm))]> {
}

class ALU_RR<CeespuOpcode opc, string opcstr, SDNode OpNode>
    : CeespuA0<opc, (outs GPR:$rd), (ins GPR:$rb, GPR:$ra),
              opcstr, "$rd, $ra, $rb",
              [(set GPR:$rd, (OpNode GPR:$ra, GPR:$rb))]> {

}

class SHIFT_RI<bits<2> shfopc, string opcstr, SDNode OpNode>
    : InstCeespu <OPC_SHF, (outs GPR:$rd), (ins GPR:$ra, u5imm:$imm),opcstr, "$rd, $ra, $imm", [(set GPR:$rd, (OpNode GPR:$ra, imm:$imm))]> {
  
  bits<5> rd;
  bits<5> ra;
  bits<5> imm;
  
  let Inst{25-21} = rd;
  let Inst{20-16} = ra;
  let Inst{7-6}  = shfopc;
  let Inst{4-0}  = imm;
}

class SHIFT_RR<bits<2> shfopc, string opcstr, SDNode OpNode>
    : CeespuA0<OPC_SHF, (outs GPR:$rd), (ins GPR:$rb, GPR:$ra),
              opcstr, "$rd, $ra, $rb",
              [(set GPR:$rd, (OpNode i32:$rb, i32:$ra))]> {
  let Inst{7-6} = shfopc;
}



let isAsCheapAsAMove = 1 in {
  def ADD : ALU_RR<OPC_ADD, "add", add>;
  def ADC : ALU_RR<OPC_ADC, "adc", adde>;
  def ADE : ALU_RR<OPC_ADD, "add", addc>;
  def SUB : ALU_RR<OPC_SUB, "sub", sub>;
  def SBB : ALU_RR<OPC_SUB, "sub", subc>;
  def SBE : ALU_RR<OPC_SUB, "sbb", sube>;
  def OR  : ALU_RR<OPC_OR , "or",  or>;
  def AND : ALU_RR<OPC_AND, "and", and>;
  def XOR : ALU_RR<OPC_XOR, "xor", xor>;
  def SHL : SHIFT_RR<0b00,  "shl", shl>; 
  def SHR : SHIFT_RR<0b01,  "shr", srl>; 
  def SAR : SHIFT_RR<0b10,  "sar", sra>; 
}
  def MUL : ALU_RR<OPC_MUL, "mul", mul>;

let isAsCheapAsAMove = 1 in {
  def ADDI : ALU_RI<OPC_ADD, "addi", add>;
  def ADCI : ALU_RI<OPC_ADC, "adci", adde>;
  def ADEI : ALU_RI<OPC_ADD, "addi", addc>;
  def SUBI : ALU_RI<OPC_SUB, "subi", sub>;
  def SBBI : ALU_RI<OPC_SUB, "subi", subc>;
  def SBEI : ALU_RI<OPC_SUB, "sbbi", sube>;
  def ORI  : ALU_RI<OPC_OR , "ori",  or>;
  def ANDI : ALU_RI<OPC_AND, "andi", and>;
  def XORI : ALU_RI<OPC_XOR, "xori", xor>;
  def SHLI : SHIFT_RI<0b00,  "shli", shl>;  
  def SHRI : SHIFT_RI<0b01,  "shri", srl>; 
  def SARI : SHIFT_RI<0b10,  "sari", sra>; 
}
  def MULI : ALU_RI<OPC_MUL, "muli", mul>;

// define instruction with 32 bit immidiates as pseudo instructions,
// they will later be lowered to SETHI, INST pairs
  def ADDX : ALU_RI_EXT<OPC_ADD, "addi", add>; 
  def ADCX : ALU_RI_EXT<OPC_ADC, "adci", adde>;
  def ADEX : ALU_RI_EXT<OPC_ADD, "addi", addc>;
  def SUBX : ALU_RI_EXT<OPC_SUB, "subi", sub>;
  def SBBX : ALU_RI_EXT<OPC_SUB, "subi", subc>;
  def SBEX : ALU_RI_EXT<OPC_SUB, "sbbi", sube>;
  def ORX  : ALU_RI_EXT<OPC_OR , "ori",  or>;
  def ANDX : ALU_RI_EXT<OPC_AND, "andi", and>;
  def XORX : ALU_RI_EXT<OPC_XOR, "xori", xor>;
  def MULX : ALU_RI_EXT<OPC_MUL, "muli", mul>;

def MOV : InstAlias<"mov $rd, $ra", (ADDI GPR:$rd, GPR:$ra, 0)>;
def NOP : InstAlias<"nop", (ADD R1, R1, R0)>;
def NOT : InstAlias<"not $rd, $ra", (XORI GPR:$rd, GPR:$ra, -1)>;
def SEXT8 : CeespuA2<OPC_SE, (outs GPR:$rd), (ins GPR:$ra),
              "seb", "$rd, $ra",
              [(set GPR:$rd, (sext_inreg GPR:$ra, i8))]>;
def SEXT16 : CeespuA2<OPC_SE, (outs GPR:$rd), (ins GPR:$ra),
             "seh", "$rd, $ra",
              [(set GPR:$rd, (sext_inreg GPR:$ra, i16))]>{
                let Inst{0} = 1; 
              }
def SETHI : CeespuB2<OPC_SETI, (outs), (ins i16imm:$imm), "seti", "$imm", []>;

/*def FI_ri
    : Pseudo<(outs GPR:$rd), (ins MEMri:$addr),
               "lea", "$rd, $addr",
               [(set i32:$rd, FIri:$addr)]> {
  // This is a tentative instruction, and will be replaced
  // with MOV_rr and ADD_ri in PEI phase
}*/

// STORE instructions
class STORE<CeespuOpcode opc, string opcstr, PatFrag OpNode>
    : CeespuB2<opc, (outs), (ins GPR:$ra, MEMri:$addr),
             opcstr ,"$ra, $addr", [(OpNode GPR:$ra, ADDR:$addr)]>;


def SH : STORE<OPC_SH, "sh", truncstorei16>;
def SB : STORE<OPC_SB, "sb", truncstorei8>;
def SW : STORE<OPC_SW, "sw", store>;

// LOAD instructions
class LOAD<CeespuOpcode opc, string opcstr, PatFrag OpNode>
    : CeespuB0<opc, (outs GPR:$rd), (ins MEMri:$addr),
              opcstr, "$rd, $addr", [(set i32:$rd, (OpNode ADDR:$addr))]>; 


def LW : LOAD<OPC_LW,  "lw", load>;

def LH : LOAD<OPC_LH,  "lh", sextloadi16>;
def LHU: LOAD<OPC_LHU, "lhu",zextloadi16>;
def LB : LOAD<OPC_LB,  "lb", sextloadi8>;
def LBU: LOAD<OPC_LBU, "lbu",zextloadi8>;

// ADJCALLSTACKDOWN/UP pseudo insns
let Defs = [SP], Uses = [SP, LR] in {
def ADJCALLSTACKDOWN : Pseudo<(outs), (ins i32imm:$amt1, i32imm:$amt2),
                              "#ADJCALLSTACKDOWN", "$amt1 $amt2",
                              [(Ceespucallseq_start timm:$amt1, timm:$amt2)]>;
def ADJCALLSTACKUP   : Pseudo<(outs), (ins i32imm:$amt1, i32imm:$amt2),
                              "#ADJCALLSTACKUP", "$amt1 $amt2",
                              [(Ceespucallseq_end timm:$amt1, timm:$amt2)]>;
}


let usesCustomInserter = 1 in {
  def Select : Pseudo<(outs GPR:$rd),
                      (ins GPR:$lhs, GPR:$rhs, i32imm:$imm, GPR:$ra, GPR:$rb),
                      "# Select PSEUDO", "$rd = $lhs $imm $rhs ? $ra : $rb",
                      [(set i32:$rd,
                       (Ceespuselectcc i32:$lhs, i32:$rhs, (i32 imm:$imm), i32:$ra, i32:$rb))]>;
}

// load global addr into register
def : Pat<(CeespuWrapper tglobaladdr:$in), (ORX R0,  tglobaladdr:$in)>;
// load ext addr into register
def : Pat<(CeespuWrapper texternalsym:$in), (ORX R0,  texternalsym:$in)>;
// load jumptableentry into register
def : Pat<(CeespuWrapper tjumptable:$in), (ORX R0,  tjumptable:$in)>;


// Zero immidiate
def : Pat<(i32 0), (i32 R0)>;

def : Pat<(i32 imm:$imm), (ORX R0 ,imm:$imm)>;
//def : Pat
// Arbitrary immediates
// def : Pat<(i32 imm:$imm), (ORI (SETHI (HI16 imm:$imm)),(LO16 imm:$imm))>;

//define not as xor with all ones
def : Pat<(not GPR:$rd),
 (XORI GPR:$rd, -1)>;

// 0xffff doesn't fit into simm16, optimize common case
def : Pat<(i32 (and (i32 GPR:$ra), 0xffff)),
          (SHRI (SHLI (i32 GPR:$ra), 16), 16)>;

// Calls
def : Pat<(Ceespucall tglobaladdr:$rd), (JAL tglobaladdr:$rd)>;
def : Pat<(Ceespucall texternalsym:$rd), (JAL texternalsym:$rd)>;

// Loads
def : Pat<(extloadi8  tglobaladdr:$ra), (i32 (LB ADDR:$ra))>;
def : Pat<(extloadi16 tglobaladdr:$ra), (i32 (LH ADDR:$ra))>;
def : Pat<(extloadi32 tglobaladdr:$ra), (i32 (LW ADDR:$ra))>;

def : Pat<(extloadi8  ADDR:$ra), (i32 (LB ADDR:$ra))>;
def : Pat<(extloadi16 ADDR:$ra), (i32 (LH ADDR:$ra))>;
def : Pat<(extloadi32 ADDR:$ra), (i32 (LW ADDR:$ra))>;
