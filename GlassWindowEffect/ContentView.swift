//
//  ContentView.swift
//  GlassWindowEffect
//
//  Created by Jared Davidson on 9/11/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                GlassWindowView()
                    .frame(width: 200, height: 400)
            }
        }
    }
}
