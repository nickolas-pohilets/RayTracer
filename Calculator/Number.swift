//
//  Expr.swift
//  Calculator
//
//  Created by Mykola Pokhylets on 26/12/2024.
//

struct DotProtuct: Hashable, Comparable, TextOutputStreamable {
    var lhs: String
    var rhs: String

    init(lhs: String, rhs: String) {
        if lhs < rhs {
            self.lhs = lhs
            self.rhs = rhs
        } else {
            self.lhs = rhs
            self.rhs = lhs
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.lhs < rhs.lhs { return true }
        if lhs.lhs != rhs.lhs { return false }
        return lhs.rhs < rhs.rhs
    }

    func write<Target: TextOutputStream>(to target: inout Target) {
        lhs.write(to: &target)
        " • ".write(to: &target)
        rhs.write(to: &target)
    }

    var isUnit: Bool {
        return lhs == rhs && lhs.starts(with: "_")
    }
}

struct NumberTerm: Term {
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.variables.lexicographicallyPrecedes(rhs.variables) { return true }
        if lhs.variables != rhs.variables { return false }
        if lhs.dotProducts.lexicographicallyPrecedes(rhs.dotProducts) { return true }
        if lhs.dotProducts != rhs.dotProducts { return false }
        return lhs.constant < rhs.constant
    }

    private(set) var variables: [String] = []
    private(set) var dotProducts: [DotProtuct] = []
    private(set) var constant: Double = 1.0

    init() {}

    init(variable: String) {
        self.variables = [variable]
    }

    init(constant: Double) {
        self.constant = constant
    }

    init(negating another: Self) {
        self.variables = another.variables
        self.dotProducts = another.dotProducts
        self.constant = -another.constant
    }

    init(multiplying lhs: Self, by rhs: Self, dotProduct: DotProtuct? = nil) {
        variables = lhs.variables + rhs.variables
        variables.sort()
        dotProducts = lhs.dotProducts + rhs.dotProducts
        if let dotProduct, !dotProduct.isUnit {
            dotProducts.append(dotProduct)
        }
        dotProducts.sort()
        constant = lhs.constant * rhs.constant
    }

    init?(removingPower n: Int, of variable: String, from another: Self) {
        let k = another.variables.count(where: { $0 == variable })
        if k != n { return nil }
        variables = another.variables.filter { $0 != variable }
        dotProducts = another.dotProducts
        constant = another.constant
    }

    mutating func merge(with another: Self) -> Bool {
        if variables != another.variables { return false }
        if dotProducts != another.dotProducts { return false }
        constant += another.constant
        return true
    }

    var isZero: Bool { constant.isZero }
    var isNegative: Bool { constant < 0 }
    var isOne: Bool { return constant == 1 && variables.isEmpty && dotProducts.isEmpty }

    func write<Target: TextOutputStream>(to target: inout Target) {
        var isFirst: Bool = true
        if constant == -1 {
            "-".write(to: &target)
        } else if constant != 1 {
            constant.write(to: &target)
            isFirst = false
        }
        for v in self.variables {
            if isFirst {
                isFirst = false
            } else {
                " * ".write(to: &target)
            }
            v.write(to: &target)
        }
        for dp in dotProducts {
            if isFirst {
                isFirst = false
            } else {
                " * ".write(to: &target)
            }
            dp.write(to: &target)
        }
        if isFirst {
            "1".write(to: &target)
        }
    }
}

typealias Number = Sum<NumberTerm>

extension Number {
    init(_ name: String) {
        self.init(singleTerm: NumberTerm(variable: name))
    }

    init(_ value: Double) {
        self.init(singleTerm: NumberTerm(constant: value))
    }

    static func *(_ lhs: Self, _ rhs: Self) -> Self {
        Self(multiplying: lhs, by: rhs) { NumberTerm(multiplying: $0, by: $1) }
    }

    func squared() -> Self {
        return self * self
    }
}
