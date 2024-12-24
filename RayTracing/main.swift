//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation


func makeGradient() -> Image {
    var image = Image(width: 256, height: 256)
    for i in 0..<image.height {
        for j in 0..<image.width {
            image[i, j] = ColorU8(r: UInt8(i), g: UInt8(j), b: 0)
        }
    }
    return image
}

func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}

try makeGradient().writePPM(to: getURL("results/dummy.ppm"))


