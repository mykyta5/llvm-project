; RUN: llc < %s -mtriple=bpf -mcpu=v1 | FileCheck --check-prefixes=CHECK,CHECK-SHIFT,CHECK-NOALU32 %s
; RUN: llc < %s -mtriple=bpf -mcpu=v2 | FileCheck --check-prefixes=CHECK,CHECK-SHIFT,CHECK-NOALU32 %s
; RUN: llc < %s -mtriple=bpf -mcpu=v3 | FileCheck --check-prefixes=CHECK,CHECK-SHIFT,CHECK-V3 %s
; RUN: llc < %s -mtriple=bpf -mcpu=v4 | FileCheck --check-prefixes=CHECK,CHECK-V4 %s

; Extension of i32 stack arguments with signext/zeroext attributes. With
; and without ALU32, i32 stack arguments are promoted to i64: the caller
; extends them to the full 64-bit slot, and the callee relies on that.

declare i64 @ext(i64, i64, i64, i64, i64, i32 zeroext, i32 signext)

define i64 @caller(i64 %v) {
  %t = trunc i64 %v to i32
  %r = call i64 @ext(i64 1, i64 2, i64 3, i64 4, i64 5, i32 zeroext %t, i32 signext %t)
  ret i64 %r
}
; CHECK-LABEL: caller:
; CHECK-SHIFT:   r[[Z:[0-9]+]] >>= 32
; CHECK-SHIFT:   *(u64 *)(r11 - 8) = r[[Z]]
; CHECK-SHIFT:   r[[S:[0-9]+]] s>>= 32
; CHECK-SHIFT:   *(u64 *)(r11 - 16) = r[[S]]
; CHECK-V4:      r[[Z:[0-9]+]] >>= 32
; CHECK-V4:      *(u64 *)(r11 - 8) = r[[Z]]
; CHECK-V4:      r[[S:[0-9]+]] = (s32)r{{[0-9]+}}
; CHECK-V4:      *(u64 *)(r11 - 16) = r[[S]]
; CHECK:         call ext

define i64 @callee(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i32 zeroext %f, i32 signext %g) {
  %x = zext i32 %f to i64
  %y = sext i32 %g to i64
  %r = xor i64 %x, %y
  ret i64 %r
}
; CHECK-LABEL: callee:
; CHECK:         r0 = *(u64 *)(r11 + 8)
; CHECK-NEXT:    r1 = *(u64 *)(r11 + 16)
; CHECK-NEXT:    r0 ^= r1
; CHECK-NEXT:    exit

; With ALU32, a signext i16 register argument is only known to be
; sign-extended within its 32-bit subregister. Forwarding it as a stack
; argument must sign-extend it to the full slot. In C:
;   long fwd(short s) { return ext16(1, 2, 3, 4, 5, s); }

declare i64 @ext16(i64, i64, i64, i64, i64, i16 signext)

define i64 @fwd(i16 signext %s) {
  %r = call i64 @ext16(i64 1, i64 2, i64 3, i64 4, i64 5, i16 signext %s)
  ret i64 %r
}
; CHECK-LABEL:  fwd:
; CHECK-NOALU32:  *(u64 *)(r11 - 8) = r1
; CHECK-V3:       r1 = w1
; CHECK-V3-NEXT:  r1 <<= 32
; CHECK-V3-NEXT:  r1 s>>= 32
; CHECK-V3-NEXT:  *(u64 *)(r11 - 8) = r1
; CHECK-V4:       r1 = (s32)r1
; CHECK-V4-NEXT:  *(u64 *)(r11 - 8) = r1
; CHECK:          call ext16
