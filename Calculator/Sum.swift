//
//  Sum.swift
//  Calculator
//
//  Created by Mykola Pokhylets on 27/12/2024.
//

protocol Term: Hashable, Comparable, TextOutputStreamable {
    init(negating: Self)
    init?(removingPower n: Int, of variable: String, from another: Self)
    mutating func merge(with another: Self) -> Bool
    var isZero: Bool { get }
    var isNegative: Bool { get }

}

struct Sum<T: Term>: Hashable, TextOutputStreamable, Comparable {
    private(set) var terms: [T] = []

    private init(terms: [T]) {
        self.terms = terms
    }

    init(singleTerm: T) {
        self.terms = [singleTerm]
    }


    init(adding lhs: Self, to rhs: Self) {
        self.terms = lhs.terms + rhs.terms
        self.normalize()
    }

    init(negating n: Self) {
        self.terms = n.terms.map { T(negating: $0) }
        assert(terms == terms.sorted())
    }

    init<U, V>(multiplying lhs: Sum<U>, by rhs: Sum<V>, using op: (U, V) -> T) {
        terms = []
        for t1 in lhs.terms {
            for t2 in rhs.terms {
                terms.append(op(t1, t2))
            }
        }
        self.normalize()
    }

    private mutating func normalize() {
        terms.sort()
        var i = 0
        for j in 1..<terms.count {
            if !terms[i].merge(with: terms[j]) {
                i += 1
                if i != j {
                    terms[i] = terms[j]
                }
            }
        }
        terms.removeLast(terms.count - i - 1)
        terms.removeAll(where: \.isZero)
    }

    static func +(_ lhs: Self, _ rhs: Self) -> Self {
        Self(adding: lhs, to: rhs)
    }

    static func -(_ lhs: Self, _ rhs: Self) -> Self {
        return lhs + Self(negating: rhs)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.terms.lexicographicallyPrecedes(rhs.terms)
    }

    func write<Target: TextOutputStream>(to target: inout Target) {
        if terms.isEmpty {
            0.write(to: &target)
        } else {
            var isFirst: Bool = true
            for t in terms {
                if isFirst {
                    t.write(to: &target)
                    isFirst = false
                } else {
                    if t.isNegative {
                        " - ".write(to: &target)
                        T(negating: t).write(to: &target)
                    } else {
                        " + ".write(to: &target)
                        t.write(to: &target)
                    }
                }
            }
        }
    }

    func coefficientForPower(_ n: Int, of variable: String) -> Self {
        return Self(terms: terms.compactMap { T(removingPower: n, of: variable, from: $0) })
    }
}
