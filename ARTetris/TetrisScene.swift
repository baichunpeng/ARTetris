//
//  TetrisScene.swift
//  ARTetris
//
//  Created by Yuri Strot on 6/29/17.
//  Copyright © 2017 Exyte. All rights reserved.
//

import Foundation
import SceneKit

class TetrisScene {
	
	let cell : Float = 0.05
	let colors : [UIColor] = [.cyan, .blue, .orange, .yellow, .green, .purple, .red]
	
	let scene: SCNScene
	let x: Float
	let y: Float
	let z: Float
	
	var nodesByLines: [[SCNNode]] = []
	var recent: SCNNode!
	
	init(_ scene: SCNScene, _ center: SCNVector3, _ well: TetrisWell) {
		self.scene = scene
		self.x = center.x
		self.y = center.y
		self.z = center.z
		addMarkers(well.width)
	}
	
	func show(_ state: TetrisState) {
		recent?.removeFromParentNode()
		recent = SCNNode()
		let tetromino = state.tetromino()
		for i in 0...3 {
			recent.addChildNode(newBox(state, tetromino.x(i), tetromino.y(i)))
		}
		scene.rootNode.addChildNode(recent)
	}
	
	func merge(_ state: TetrisState) {
		recent?.removeFromParentNode()
		let tetromino = state.tetromino()
		for i in 0...3 {
			let box = newBox(state, tetromino.x(i), tetromino.y(i))
			scene.rootNode.addChildNode(box)
			let row = tetromino.y(i) + state.y
			while(nodesByLines.count <= row) {
				nodesByLines.append([])
			}
			nodesByLines[row].append(box)
		}
	}
	
	func removeRows(_ rows: [Int]) -> CFTimeInterval {
		let time = 0.2
		let opacity = CABasicAnimation(keyPath: "opacity")
		opacity.fromValue = 1
		opacity.toValue = 0
		opacity.duration = time
		opacity.fillMode = kCAFillModeForwards
		opacity.isRemovedOnCompletion = false
		for row in rows {
			for node in nodesByLines[row] {
				node.addAnimation(opacity, forKey: nil)
			}
		}
		Timer.scheduledTimer(withTimeInterval: time, repeats: false) { _ in
			self.addScores(rows.count, rows.first!)
			for (index, row) in rows.reversed().enumerated() {
				let nextRow = index + 1 < rows.count ? rows[index + 1] : self.nodesByLines.count
				if (nextRow > row + 1) {
					for j in row + 1..<nextRow {
						for node in self.nodesByLines[j] {
							let translate = CABasicAnimation(keyPath: "position.y")
							let y = self.y + Float(j) * self.cell
							translate.fromValue = y
							translate.toValue = y - self.cell * Float(index + 1)
							translate.duration = time
							translate.fillMode = kCAFillModeForwards
							translate.isRemovedOnCompletion = false
							node.addAnimation(translate, forKey: nil)
						}
					}
				}
			}
			for row in rows {
				for node in self.nodesByLines[row] {
					node.removeFromParentNode()
				}
				self.nodesByLines.remove(at: row)
			}
		}
		return time * 2
	}
	
	func drop(delta: Int, max: Int) -> CFTimeInterval {
		let move = CABasicAnimation(keyPath: "position.y")
		move.fromValue = 0
		move.toValue = Float(-delta) * cell
		let percent = Double(delta - 1) / Double(max - 1)
		move.duration = percent * 0.3 + 0.1
		recent.addAnimation(move, forKey: nil)
		return move.duration
	}
	
	func destroy() {
		addFloor()
		scene.physicsWorld.gravity = SCNVector3Make(0, -2, 0)
		for i in 0..<nodesByLines.count {
			let z = Float((Int(arc4random_uniform(3)) - 1) * i) * -0.01
			let x = Float((Int(arc4random_uniform(3)) - 1) * i) * -0.01
			let direction = SCNVector3Make(x, 0, z)
			for item in nodesByLines[i] {
				item.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
				item.physicsBody?.angularDamping = 0.9
				item.physicsBody?.applyForce(direction, asImpulse: true)
			}
		}
	}
	
	private func addScores(_ rows: Int, _ row: Int) {
		let text = SCNText(string: "+\(self.getScores(rows))", extrusionDepth: 1)
		text.font = UIFont.systemFont(ofSize: 20)
		let textNode = SCNNode(geometry: text)
		
		let material = SCNMaterial()
		material.diffuse.contents = UIColor.white
		text.materials = [material, material, material, material]
		
		let y = Float(row) * self.cell
		textNode.transform = SCNMatrix4Scale(SCNMatrix4Translate(self.translate(0, 0), 5 * cell, y, 2 * cell), 0.001, 0.001, 0.001)
		
		let translate = CABasicAnimation(keyPath: "position.y")
		translate.fromValue = textNode.transform.m42
		translate.toValue = textNode.transform.m42 + cell * 4
		translate.duration = 2
		translate.fillMode = kCAFillModeForwards
		translate.isRemovedOnCompletion = false
		textNode.addAnimation(translate, forKey: nil)
		
		let opacity = CABasicAnimation(keyPath: "opacity")
		opacity.fromValue = 1
		opacity.toValue = 0
		opacity.duration = 2
		opacity.fillMode = kCAFillModeForwards
		opacity.isRemovedOnCompletion = false
		textNode.addAnimation(opacity, forKey: nil)
		
		self.scene.rootNode.addChildNode(textNode)
	}
	
	private func getScores(_ rows: Int) -> Int {
		switch rows {
		case 1:
			return 100
		case 2:
			return 300
		case 3:
			return 500
		default:
			return 800
		}
	}
	
	private func addMarkers(_ width: Int) {
		for i in 1...width {
			addMarker(i, 0)
		}
	}
	
	private func newBox(_ state: TetrisState, _ x: Int, _ y: Int) -> SCNNode {
		let box = SCNBox(width: CGFloat(cell), height: CGFloat(cell), length: CGFloat(cell), chamferRadius: 0.005)
		let node = SCNNode(geometry: box)
		node.transform = SCNMatrix4Translate(translate(state.x, state.y), Float(x) * cell, Float(y) * cell - cell / 2, 0)
		
		let material = SCNMaterial()
		material.diffuse.contents = colors[state.index]
		box.materials = [material, material, material, material, material, material]
		return node
	}
	
	private func addMarker(_ x: Int, _ y: Int) {
		let plane = SCNPlane(width: 0.045, height: 0.045)
		let planeNode = SCNNode(geometry: plane)
		
		let material = SCNMaterial()
		material.diffuse.contents = UIColor.gray
		material.transparency = 0.3
		plane.materials = [material, material]
		
		// SCNPlanes are vertically oriented in their local coordinate space.
		// Rotate it to match the horizontal orientation of the ARPlaneAnchor.
		let matrix = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
		planeNode.transform = SCNMatrix4Mult(matrix, translate(x, y))
		
		// ARKit owns the node corresponding to the anchor, so make the plane a child node.
		scene.rootNode.addChildNode(planeNode)
	}
	
	private func addFloor() {
		let size : CGFloat = 10
		let plane = SCNPlane(width: size, height: size)
		let planeNode = SCNNode(geometry: plane)
		
		let material = SCNMaterial()
		material.diffuse.contents = UIColor.gray
		material.transparency = 0
		plane.materials = [material, material]
		
		// SCNPlanes are vertically oriented in their local coordinate space.
		// Rotate it to match the horizontal orientation of the ARPlaneAnchor.
		let matrix = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
		planeNode.transform = SCNMatrix4Mult(matrix, translate(0, 0))
		planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
		planeNode.physicsBody?.friction = 1
		scene.rootNode.addChildNode(planeNode)
	}
	
	private func translate(_ x: Int, _ y: Int) -> SCNMatrix4 {
		return SCNMatrix4MakeTranslation(self.x + Float(x) * cell, self.y + Float(y) * cell + cell / 2, self.z)
	}
	
}
