//===-- CeespuMCCodeEmitter.cpp - Convert Ceespu code to machine code
//-------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the CeespuMCCodeEmitter class.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/CeespuBaseInfo.h"
#include "MCTargetDesc/CeespuFixupKinds.h"
#include "MCTargetDesc/CeespuMCExpr.h"
#include "MCTargetDesc/CeespuMCTargetDesc.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "mccodeemitter"

STATISTIC(MCNumEmitted, "Number of MC instructions emitted");
STATISTIC(MCNumFixups, "Number of MC fixups created");

namespace {
class CeespuMCCodeEmitter : public MCCodeEmitter {
  CeespuMCCodeEmitter(const CeespuMCCodeEmitter &) = delete;
  void operator=(const CeespuMCCodeEmitter &) = delete;
  MCContext &Ctx;
  const MCRegisterInfo &MRI;
  MCInstrInfo const &MCII;

 public:
  CeespuMCCodeEmitter(MCContext &ctx, MCInstrInfo const &MCII,
                      MCRegisterInfo const &MRI)
      : Ctx(ctx), MCII(MCII), MRI(MRI) {}

  ~CeespuMCCodeEmitter() override {}

  void encodeInstruction(const MCInst &MI, raw_ostream &OS,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override;

  void expandFunctionCall(const MCInst &MI, raw_ostream &OS,
                          SmallVectorImpl<MCFixup> &Fixups,
                          const MCSubtargetInfo &STI) const;

  /// TableGen'erated function for getting the binary encoding for an
  /// instruction.
  uint64_t getBinaryCodeForInstr(const MCInst &MI,
                                 SmallVectorImpl<MCFixup> &Fixups,
                                 const MCSubtargetInfo &STI) const;

  /// Return binary encoding of operand. If the machine operand requires
  /// relocation, record the relocation and return zero.
  unsigned getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;

  unsigned getImmOpValueAsr1(const MCInst &MI, unsigned OpNo,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;

  unsigned getImmOpValue(const MCInst &MI, unsigned OpNo,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const;
  // Encode BPF Memory Operand
  uint64_t getMemoryOpValue(const MCInst &MI, unsigned Op,
                            SmallVectorImpl<MCFixup> &Fixups,
                            const MCSubtargetInfo &STI) const;
};
}  // end anonymous namespace

MCCodeEmitter *llvm::createCeespuMCCodeEmitter(const MCInstrInfo &MCII,
                                               const MCRegisterInfo &MRI,
                                               MCContext &Ctx) {
  return new CeespuMCCodeEmitter(Ctx, MCII, MRI);
}

// Expand PseudoCALL and PseudoTAIL to AUIPC and JALR with relocation types.
// We expand PseudoCALL and PseudoTAIL while encoding, meaning AUIPC and JALR
// won't go through Ceespu MC to MC compressed instruction transformation. This
// is acceptable because AUIPC has no 16-bit form and C_JALR have no immediate
// operand field.  We let linker relaxation deal with it. When linker
// relaxation enabled, AUIPC and JALR have chance relax to JAL. If C extension
// is enabled, JAL has chance relax to C_JAL.
void CeespuMCCodeEmitter::expandFunctionCall(const MCInst &MI, raw_ostream &OS,
                                             SmallVectorImpl<MCFixup> &Fixups,
                                             const MCSubtargetInfo &STI) const {
  /*MCInst TmpInst;
  MCOperand Func = MI.getOperand(0);
  unsigned Ra =
      (MI.getOpcode() == Ceespu::PseudoTAIL) ? Ceespu::LR : Ceespu::X1;
  uint32_t Binary;

  assert(Func.isExpr() && "Expected expression");

  const MCExpr *Expr = Func.getExpr();

  // Create function call expression CallExpr for AUIPC.
  const MCExpr *CallExpr =
      CeespuMCExpr::create(Expr, CeespuMCExpr::VK_Ceespu_CALL, Ctx);

  // Emit AUIPC Ra, Func with R_Ceespu_CALL relocation type.
  TmpInst = MCInstBuilder(Ceespu::AUIPC)
                .addReg(Ra)
                .addOperand(MCOperand::createExpr(CallExpr));
  Binary = getBinaryCodeForInstr(TmpInst, Fixups, STI);
  support::endian::write(OS, Binary, support::little);

  // Emit JALR Ra, Ra, 0
  TmpInst = MCInstBuilder(Ceespu::JALR).addReg(Ra).addReg(Ra).addImm(0);
  Binary = getBinaryCodeForInstr(TmpInst, Fixups, STI);
  support::endian::write(OS, Binary, support::little);*/
}

void CeespuMCCodeEmitter::encodeInstruction(const MCInst &MI, raw_ostream &OS,
                                            SmallVectorImpl<MCFixup> &Fixups,
                                            const MCSubtargetInfo &STI) const {
  const MCInstrDesc &Desc = MCII.get(MI.getOpcode());
  // Get byte count of instruction.
  unsigned Size = Desc.getSize();

  /*if (MI.getOpcode() == Ceespu::PseudoCALL ||
      MI.getOpcode() == Ceespu::PseudoTAIL) {
    expandFunctionCall(MI, OS, Fixups, STI);
    MCNumEmitted += 2;
    return;
  }*/

  switch (Size) {
    default:
      llvm_unreachable("Unhandled encodeInstruction length!");
    case 2: {
      uint16_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
      support::endian::write<uint16_t>(OS, Bits, support::little);
      break;
    }
    case 4: {
      uint32_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
      support::endian::write(OS, Bits, support::little);
      break;
    }
  }

  ++MCNumEmitted;  // Keep track of the # of mi's emitted.
}

unsigned CeespuMCCodeEmitter::getMachineOpValue(
    const MCInst &MI, const MCOperand &MO, SmallVectorImpl<MCFixup> &Fixups,
    const MCSubtargetInfo &STI) const {
  if (MO.isReg()) return Ctx.getRegisterInfo()->getEncodingValue(MO.getReg());

  if (MO.isImm()) return static_cast<unsigned>(MO.getImm());

  llvm_unreachable("Unhandled expression!");
  return 0;
}

unsigned CeespuMCCodeEmitter::getImmOpValueAsr1(
    const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
    const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);

  if (MO.isImm()) {
    unsigned Res = MO.getImm();
    assert((Res & 1) == 0 && "LSB is non-zero");
    return Res >> 1;
  }

  return getImmOpValue(MI, OpNo, Fixups, STI);
}

unsigned CeespuMCCodeEmitter::getImmOpValue(const MCInst &MI, unsigned OpNo,
                                            SmallVectorImpl<MCFixup> &Fixups,
                                            const MCSubtargetInfo &STI) const {
  /* TODO ACTUALLY IMPLEMENT THIS  bool EnableRelax =
  STI.getFeatureBits()[Ceespu::FeatureRelax]; const MCOperand &MO =
  MI.getOperand(OpNo);

    MCInstrDesc const &Desc = MCII.get(MI.getOpcode());
    unsigned MIFrm = Desc.TSFlags & CeespuII::InstFormatMask;

    // If the destination is an immediate, there is nothing to do
    if (MO.isImm()) return MO.getImm();

    assert(MO.isExpr() && "getImmOpValue expects only expressions or
  immediates"); const MCExpr *Expr = MO.getExpr(); MCExpr::ExprKind Kind =
  Expr->getKind(); Ceespu::Fixups FixupKind = Ceespu::fixup_ceespu_invalid; if
  (Kind == MCExpr::Target) { const CeespuMCExpr *RVExpr =
  cast<CeespuMCExpr>(Expr);

      switch (RVExpr->getKind()) {
        case CeespuMCExpr::VK_Ceespu_None:
        case CeespuMCExpr::VK_Ceespu_Invalid:
          llvm_unreachable("Unhandled fixup kind!");
        case CeespuMCExpr::VK_Ceespu_LO:
          if (MIFrm == CeespuII::InstFormatI)
            FixupKind = Ceespu::fixup_ceespu_lo12_i;
          else if (MIFrm == CeespuII::InstFormatS)
            FixupKind = Ceespu::fixup_ceespu_lo12_s;
          else
            llvm_unreachable(
                "VK_Ceespu_LO used with unexpected instruction format");
          break;
        case CeespuMCExpr::VK_Ceespu_HI:
          FixupKind = Ceespu::fixup_ceespu_hi20;
          break;
        case CeespuMCExpr::VK_Ceespu_PCREL_LO:
          if (MIFrm == CeespuII::InstFormatI)
            FixupKind = Ceespu::fixup_ceespu_pcrel_lo12_i;
          else if (MIFrm == CeespuII::InstFormatS)
            FixupKind = Ceespu::fixup_ceespu_pcrel_lo12_s;
          else
            llvm_unreachable(
                "VK_Ceespu_PCREL_LO used with unexpected instruction format");
          break;
        case CeespuMCExpr::VK_Ceespu_PCREL_HI:
          FixupKind = Ceespu::fixup_ceespu_pcrel_hi20;
          break;
        case CeespuMCExpr::VK_Ceespu_CALL:
          FixupKind = Ceespu::fixup_ceespu_call;
          break;
      }
    } else if (Kind == MCExpr::SymbolRef &&
               cast<MCSymbolRefExpr>(Expr)->getKind() ==
                   MCSymbolRefExpr::VK_None) {
      if (Desc.getOpcode() == Ceespu::JAL) {
        FixupKind = Ceespu::fixup_ceespu_jal;
      } else if (MIFrm == CeespuII::InstFormatB) {
        FixupKind = Ceespu::fixup_ceespu_branch;
      } else if (MIFrm == CeespuII::InstFormatCJ) {
        FixupKind = Ceespu::fixup_ceespu_rvc_jump;
      } else if (MIFrm == CeespuII::InstFormatCB) {
        FixupKind = Ceespu::fixup_ceespu_rvc_branch;
      }
    }

    assert(FixupKind != Ceespu::fixup_ceespu_invalid && "Unhandled
  expression!");

    Fixups.push_back(
        MCFixup::create(0, Expr, MCFixupKind(FixupKind), MI.getLoc()));
    ++MCNumFixups;

    if (EnableRelax) {
      if (FixupKind == Ceespu::fixup_ceespu_call) {
        Fixups.push_back(MCFixup::create(
            0, Expr, MCFixupKind(Ceespu::fixup_ceespu_relax), MI.getLoc()));
        ++MCNumFixups;
      }
    }*/

  return 0;
}

// Encode BPF Memory Operand
uint64_t CeespuMCCodeEmitter::getMemoryOpValue(
    const MCInst &MI, unsigned Op, SmallVectorImpl<MCFixup> &Fixups,
    const MCSubtargetInfo &STI) const {
  uint64_t Encoding;
  const MCOperand Op1 = MI.getOperand(1);
  assert(Op1.isReg() && "First operand is not register.");
  Encoding = MRI.getEncodingValue(Op1.getReg());
  Encoding <<= 16;
  MCOperand Op2 = MI.getOperand(2);
  assert(Op2.isImm() && "Second operand is not immediate.");
  Encoding |= Op2.getImm() & 0xffff;
  return Encoding;
}

#include "CeespuGenMCCodeEmitter.inc"
