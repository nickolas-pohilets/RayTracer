//
//  main.swift
//  Calculator
//
//  Created by Nickolas Pokhylets on 25/12/2024.
//

import Foundation

// P = ray[t]
// Q = (P - baseCenter) = ray.direction * t + (ray.origin - baseCenter)
// Qp = axis * (Q • axis)
// Qr = Q - Qp
// Qr • Qr = radius²

let axis = Vector("_axis") // Normalized
let Q = Vector("d") * Number("t") + Vector("oc")
let Qp = axis * (Q • axis)
let Qr = Q - Qp
let Z = Qr • Qr - Number("radius").squared()

print(Z)
let a = Z.coefficientForPower(2, of: "t")
print("a =", a)
let b_2 = Z.coefficientForPower(1, of: "t") * Number(0.5)
print("b/2 =", b_2)
let c = Z.coefficientForPower(0, of: "t")
print("c =", c)
