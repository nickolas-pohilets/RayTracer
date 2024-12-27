//
//  Vector.swift
//  Calculator
//
//  Created by Mykola Pokhylets on 26/12/2024.
//

infix operator • : MultiplicationPrecedence

struct VectorTerm: Term {
    var scale: NumberTerm
    var vectorVariable: String

    init(scale: NumberTerm = NumberTerm(), vectorVariable: String) {
        self.scale = scale
        self.vectorVariable = vectorVariable
    }

    init(negating another: VectorTerm) {
        self.scale = NumberTerm(negating: another.scale)
        self.vectorVariable = another.vectorVariable
    }

    init?(removingPower n: Int, of variable: String, from another: Self) {
        guard let scale = NumberTerm(removingPower: n, of: variable, from: another.scale) else { return nil }
        self.scale = scale
        self.vectorVariable = another.vectorVariable
    }

    var isZero: Bool { scale.isZero }
    var isNegative: Bool { scale.isNegative }

    mutating func merge(with another: VectorTerm) -> Bool {
        if vectorVariable != another.vectorVariable { return false }
        return scale.merge(with: another.scale)
    }

    static func < (lhs: VectorTerm, rhs: VectorTerm) -> Bool {
        if lhs.vectorVariable < rhs.vectorVariable { return true }
        if lhs.vectorVariable != rhs.vectorVariable { return false }
        return lhs.scale < rhs.scale
    }

    func write<Target>(to target: inout Target) where Target : TextOutputStream {
        if scale.isNegative {
            "-".write(to: &target)
            VectorTerm(negating: self).write(to: &target)
        } else {
            if !scale.isOne {
                scale.write(to: &target)
                " * ".write(to: &target)
            }
            vectorVariable.write(to: &target)
        }
    }
}

typealias Vector = Sum<VectorTerm>

extension Vector {
    init(_ name: String) {
        self.init(singleTerm: VectorTerm(vectorVariable: name))
    }

    static func *(_ lhs: Self, _ rhs: Number) -> Self {
        Self(multiplying: lhs, by: rhs) { (lhsTerm, rhsTerm) -> VectorTerm in
            VectorTerm(scale: NumberTerm(multiplying: lhsTerm.scale, by: rhsTerm), vectorVariable: lhsTerm.vectorVariable)
        }
    }

    static func *(_ lhs: Number, _ rhs: Self) -> Self {
        Self(multiplying: lhs, by: rhs) { (lhsTerm, rhsTerm) -> VectorTerm in
            VectorTerm(scale: NumberTerm(multiplying: lhsTerm, by: rhsTerm.scale), vectorVariable: rhsTerm.vectorVariable)
        }
    }

    static func •(_ lhs: Vector, _ rhs: Vector) -> Number {
        Number(multiplying: lhs, by: rhs) { (lhsTerm, rhsTerm) -> NumberTerm in
            NumberTerm(
                multiplying: lhsTerm.scale,
                by: rhsTerm.scale,
                dotProduct: DotProtuct(lhs: lhsTerm.vectorVariable, rhs: rhsTerm.vectorVariable)
            )
        }
    }
}
