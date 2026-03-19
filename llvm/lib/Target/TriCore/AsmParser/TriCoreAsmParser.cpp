#include "MCTargetDesc/TriCoreMCTargetDesc.h"
// #include "MCTargetDesc/TriCoreTargetStreamer.h"
#include "TargetInfo/TriCoreTargetInfo.h"
#include "TriCore.h"
#include "llvm/CodeGen/Register.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCParser/MCAsmLexer.h"
#include "llvm/MC/MCParser/MCParsedAsmOperand.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCSectionWasm.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCSymbolWasm.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Endian.h"

using namespace llvm;

namespace {

class TriCoreAsmParser : public MCTargetAsmParser {

  /// @name Auto-generated Match Functions
  /// {

#define GET_ASSEMBLER_HEADER
#include "TriCoreGenAsmMatcher.inc"

  /// }

public:
  TriCoreAsmParser(const MCSubtargetInfo &STI, MCAsmParser &Parser,
                   const MCInstrInfo &MII, const MCTargetOptions &Options)
      : MCTargetAsmParser(Options, STI, MII), Parser(Parser),
        Lexer(Parser.getLexer()) {
    setAvailableFeatures(ComputeAvailableFeatures(STI.getFeatureBits()));
  }

  bool ParseDirective(llvm::AsmToken DirectiveID) override;
  llvm::OperandMatchResultTy tryParseRegister(MCRegister &Reg, SMLoc &StartLoc,
                                              SMLoc &EndLoc) override;
  bool parseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) override;
  bool MatchAndEmitInstruction(llvm::SMLoc IDLoc, unsigned int &Opcode,
                               llvm::OperandVector &Operands,
                               llvm::MCStreamer &Out, uint64_t &ErrorInfo,
                               bool MatchingInlineAsm) override;
  bool ParseInstruction(llvm::ParseInstructionInfo &Info, llvm::StringRef Name,
                        llvm::SMLoc NameLoc,
                        llvm::OperandVector &Operands) override;

  void eatComma();

private:
  MCAsmParser &Parser;
  MCAsmLexer &Lexer;
};

struct TriCoreOperand : public MCParsedAsmOperand {

  enum class KindTy {
    Token,
    Register,
    Immediate,
  };

  KindTy Kind;
  SMLoc Start, End;

  struct RegOp {
    Register RegNum;
  };

  struct ImmOp {
    const MCExpr *Val;
  };

  union {
    StringRef Tok;
    RegOp Reg;
    ImmOp Imm;
  };

  TriCoreOperand(KindTy Kind, SMLoc Start, SMLoc End)
      : MCParsedAsmOperand(), Kind(Kind), Start(Start), End(End) {}

  static std::unique_ptr<TriCoreOperand> createToken(StringRef Token,
                                                     SMLoc Start, SMLoc End);
  static std::unique_ptr<TriCoreOperand> createReg(MCRegister RegNum,
                                                   SMLoc Start, SMLoc End);
  static std::unique_ptr<TriCoreOperand> createImm(const MCExpr *Val,
                                                   SMLoc Start, SMLoc End);

  SMLoc getStartLoc() const override { return Start; }
  SMLoc getEndLoc() const override { return End; }

  void print(raw_ostream &OS) const override;

  bool isToken() const override { return Kind == KindTy::Token; }
  bool isReg() const override { return Kind == KindTy::Register; }
  bool isImm() const override { return Kind == KindTy::Immediate; }
  bool isMem() const override { return false; }

  unsigned getReg() const override {
    assert(Kind == KindTy::Register && "Invalid type access!");
    return Reg.RegNum.id();
  }

  StringRef getToken() const {
    assert(Kind == KindTy::Token && "Invalid type access!");
    return Tok;
  }

  const MCExpr *getImm() const {
    assert(Kind == KindTy::Immediate && "Invalid type access!");
    return Imm.Val;
  }

  static void addExpr(MCInst &Inst, const MCExpr *Expr) {
    if (const MCConstantExpr *CE = dyn_cast<MCConstantExpr>(Expr))
      Inst.addOperand(MCOperand::createImm(CE->getValue()));
    else
      Inst.addOperand(MCOperand::createExpr(Expr));
  }

  void addRegOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getReg()));
  }

  void addImmOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    addExpr(Inst, getImm());
  }
};
} // namespace

#define GET_REGISTER_MATCHER
#define GET_SUBTARGET_FEATURE_NAME
#define GET_MATCHER_IMPLEMENTATION
#define GET_MNEMONIC_SPELL_CHECKER
#include "TriCoreGenAsmMatcher.inc"

std::unique_ptr<TriCoreOperand>
TriCoreOperand::createToken(StringRef Token, SMLoc Start, SMLoc End) {
  auto Op = std::make_unique<TriCoreOperand>(KindTy::Token, Start, End);
  Op->Tok = Token;
  return Op;
}

std::unique_ptr<TriCoreOperand>
TriCoreOperand::createReg(MCRegister RegNum, SMLoc Start, SMLoc End) {
  auto Op = std::make_unique<TriCoreOperand>(KindTy::Register, Start, End);
  Op->Reg.RegNum = RegNum;
  return Op;
}

std::unique_ptr<TriCoreOperand>
TriCoreOperand::createImm(const MCExpr *Val, SMLoc Start, SMLoc End) {
  auto Op = std::make_unique<TriCoreOperand>(KindTy::Immediate, Start, End);
  Op->Imm.Val = Val;
  return Op;
}

void TriCoreOperand::print(raw_ostream &OS) const {
#if 0
  switch (Op) {
  case Kind::Addr:
    OS << OuterDisp;
    break;
  case Kind::RegMask:
    OS << "RegMask(" << format("%04x", RegMask) << ")";
    break;
  case Kind::Reg:
    OS << '%' << OuterReg;
    break;
  case Kind::RegIndirect:
    OS << "(%" << OuterReg << ')';
    break;
  case Kind::RegPostIncrement:
    OS << "(%" << OuterReg << ")+";
    break;
  case Kind::RegPreDecrement:
    OS << "-(%" << OuterReg << ")";
    break;
  case Kind::RegIndirectDisplacement:
    OS << OuterDisp << "(%" << OuterReg << ")";
    break;
  case Kind::RegIndirectDisplacementIndex:
    OS << OuterDisp << "(%" << OuterReg << ", " << InnerReg << "." << Size
       << ", " << InnerDisp << ")";
    break;
  }
#endif
}

bool TriCoreAsmParser::MatchAndEmitInstruction(
    llvm::SMLoc IDLoc, unsigned int &Opcode, llvm::OperandVector &Operands,
    llvm::MCStreamer &Out, uint64_t &ErrorInfo, bool MatchingInlineAsm) {
  SMLoc ErrorLoc;
  MCInst Inst;
  Inst.setLoc(IDLoc);
  FeatureBitset MissingFeatures;

  unsigned MatchResult = MatchInstructionImpl(
      Operands, Inst, ErrorInfo, MissingFeatures, MatchingInlineAsm);

  switch (MatchResult) {
  default:
    break;
  case Match_Success:
    Out.emitInstruction(Inst, getSTI());
    return false;
  case Match_MissingFeature: {
    assert(MissingFeatures.any() && "Unknown missing features!");
    bool FirstFeature = true;
    std::string Msg = "instruction requires the following:";
    for (unsigned i = 0, e = MissingFeatures.size(); i != e; ++i) {
      if (MissingFeatures[i]) {
        Msg += FirstFeature ? " " : ", ";
        Msg += getSubtargetFeatureName(i);
        FirstFeature = false;
      }
    }
    return Error(IDLoc, Msg);
  }
  case Match_MnemonicFail: {
    return Error(IDLoc, "unrecognized instruction mnemonic");
  }
  case Match_InvalidOperand: {
    SMLoc ErrorLoc = IDLoc;
    if (ErrorInfo != ~0U) {
      if (ErrorInfo >= Operands.size())
        return Error(ErrorLoc, "too few operands for instruction");
    }
    return Error(ErrorLoc, "invalid operand for instruction");
  }
  }

  llvm_unreachable("Implement any new match types added!");
}

bool TriCoreAsmParser::ParseDirective(AsmToken DirectiveID) {
  // This returns false if this function recognizes the directive
  // regardless of whether it is successfully handles or reports an
  // error. Otherwise it returns true to give the generic parser a
  // chance at recognizing it.
  StringRef IDVal = DirectiveID.getString();

  // if (IDVal == ".option")
  //   return parseDirectiveOption();
  // else if (IDVal == ".attribute")
  //   return parseDirectiveAttribute();

  return true;
}

bool TriCoreAsmParser::parseRegister(MCRegister &Reg, SMLoc &StartLoc,
                                     SMLoc &EndLoc) {
  if (tryParseRegister(Reg, StartLoc, EndLoc) != MatchOperand_Success)
    return Error(StartLoc, "invalid register name");
  return false;
}

OperandMatchResultTy TriCoreAsmParser::tryParseRegister(MCRegister &RegNo,
                                                        SMLoc &StartLoc,
                                                        SMLoc &EndLoc) {
  const AsmToken &Tok = getParser().getTok();
  StartLoc = Tok.getLoc();
  EndLoc = Tok.getEndLoc();

  // Accept both bare identifiers (D2, A4) and %-prefixed identifiers (%d2, %a4)
  // which are emitted by the InstPrinter.
  StringRef Name;
  if (Tok.is(AsmToken::Identifier)) {
    Name = Tok.getString();
  } else if (Tok.is(AsmToken::Percent)) {
    // Consume '%', then expect an identifier.
    SMLoc PctLoc = Tok.getLoc();
    getParser().Lex(); // eat '%'
    const AsmToken &NameTok = getParser().getTok();
    if (NameTok.isNot(AsmToken::Identifier)) {
      // Un-lex is not possible; report no-match (caller handles the error).
      return MatchOperand_NoMatch;
    }
    EndLoc = NameTok.getEndLoc();
    // MatchRegisterName is case-insensitive (generated matcher lowercases).
    Name = NameTok.getString();
  } else {
    return MatchOperand_NoMatch;
  }

  RegNo = MatchRegisterName(Name);
  if (RegNo == TriCore::NoRegister) {
    // If we consumed a '%', we cannot un-lex, so treat it as no-match and
    // let the caller produce an error on the next unexpected token.
    return MatchOperand_NoMatch;
  }

  getParser().Lex(); // Eat identifier token.
  return MatchOperand_Success;
}

void TriCoreAsmParser::eatComma() {
  if (Parser.getTok().is(AsmToken::Comma)) {
    Parser.Lex();
  }
}

bool TriCoreAsmParser::ParseInstruction(ParseInstructionInfo &Info,
                                        StringRef Name, SMLoc NameLoc,
                                        OperandVector &Operands) {
  Operands.push_back(TriCoreOperand::createToken(Name, NameLoc, NameLoc));

  // Return early if there are no operands.
  if (getLexer().is(AsmToken::EndOfStatement)) {
    Parser.Lex();
    return false;
  }

  bool First = true;
  while (getLexer().isNot(AsmToken::EndOfStatement)) {
    if (!First) {
      if (getLexer().isNot(AsmToken::Comma))
        return Error(getLexer().getLoc(), "expected ','");
      Parser.Lex(); // eat comma
    }
    First = false;

    // Try to parse a memory operand: [%An] offset  or  [An] offset
    // This is the TriCore load/store addressing mode.
    if (getLexer().is(AsmToken::LBrac)) {
      SMLoc MemStart = getLexer().getLoc();
      Parser.Lex(); // eat '['
      MCRegister BaseReg;
      SMLoc RS, RE;
      if (tryParseRegister(BaseReg, RS, RE) != MatchOperand_Success) {
        Parser.eatToEndOfStatement();
        return Error(getLexer().getLoc(), "expected base register after '['" );
      }
      if (getLexer().isNot(AsmToken::RBrac)) {
        Parser.eatToEndOfStatement();
        return Error(getLexer().getLoc(), "expected ']'");
      }
      Parser.Lex(); // eat ']'
      // Optional offset (integer expression).
      const MCExpr *OffExpr =
          MCConstantExpr::create(0, getContext());
      // Offset may follow directly (no space) or after whitespace.
      if (getLexer().is(AsmToken::Integer) ||
          getLexer().is(AsmToken::Minus)  ||
          getLexer().is(AsmToken::Plus)) {
        SMLoc OStart = getLexer().getLoc();
        if (getParser().parseExpression(OffExpr)) {
          Parser.eatToEndOfStatement();
          return Error(OStart, "invalid offset expression");
        }
      }
      SMLoc MemEnd = getLexer().getLoc();
      // Encode as two operands: base register + immediate offset.
      Operands.push_back(TriCoreOperand::createReg(BaseReg, MemStart, MemEnd));
      Operands.push_back(TriCoreOperand::createImm(OffExpr, MemStart, MemEnd));
      continue;
    }

    // Try to parse a register operand.
    MCRegister RegNo;
    SMLoc RegStart, RegEnd;
    if (tryParseRegister(RegNo, RegStart, RegEnd) == MatchOperand_Success) {
      Operands.push_back(TriCoreOperand::createReg(RegNo, RegStart, RegEnd));
      continue;
    }

    // Try to parse an immediate/expression operand.
    SMLoc ExprStart = getLexer().getLoc();
    const MCExpr *Expr;
    if (!getParser().parseExpression(Expr)) {
      SMLoc ExprEnd = getLexer().getLoc();
      Operands.push_back(TriCoreOperand::createImm(Expr, ExprStart, ExprEnd));
      continue;
    }

    SMLoc Loc = getLexer().getLoc();
    Parser.eatToEndOfStatement();
    return Error(Loc, "unexpected token parsing operands");
  }

  // Eat EndOfStatement.
  Parser.Lex();
  return false;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeTriCoreAsmParser() {
  RegisterMCAsmParser<TriCoreAsmParser> A(getTheTriCoreTarget());
}
