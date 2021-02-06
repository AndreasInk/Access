//
//  ContentView.swift
//  Access
//
//  Created by Andreas on 2/6/21.
//
import SwiftUI
import RealityKit
import PencilKit
import ARKit
import Vision
import AVFoundation

struct ContentView : View {
    
    let pkCanvas = PKCanvasRepresentation()
    @State var digitPredicted = "NA"
    
   
    
    var body: some View {
        VStack{
            ARViewContainer(overlayText: $digitPredicted).edgesIgnoringSafeArea(.all)
            

            HStack{

            Button(action: {
                let image = self.pkCanvas.canvasView.drawing.image(from: self.pkCanvas.canvasView.drawing.bounds, scale: 1.0)

                self.recognizeTextInImage(image)
                self.pkCanvas.canvasView.drawing = PKDrawing()

            }){
                Text("Extract Digit")
            }.buttonStyle(MyButtonStyle(color: .blue))

                Text(digitPredicted)

            }
            
        }
    }
    
    private func recognizeTextInImage(_ image: UIImage) {
        
       
    }
}



class CustomBox: Entity, HasModel, HasAnchoring, HasCollision {
    
    required init(color: UIColor) {
        super.init()
        self.components[ModelComponent] = ModelComponent(
            mesh: .generateBox(size: 0.1),
            materials: [SimpleMaterial(
                color: color,
                isMetallic: false)
            ]
        )
    }
    
    convenience init(color: UIColor, position: SIMD3<Float>) {
        self.init(color: color)
        self.position = position
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
}



struct ARViewContainer: UIViewRepresentable {
    
    @Binding var overlayText: String
    
    func makeCoordinator() -> ARViewCoordinator{
        ARViewCoordinator(self, overlayText : $overlayText)
    }
    
    func makeUIView(context: Context) -> ARView {
        
        
        let arView = ARView(frame: .zero)
        arView.addCoaching()
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        arView.session.run(config, options: [])
        
        arView.setupGestures()
        arView.session.delegate = context.coordinator
        
        return arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {
    }
}



class ARViewCoordinator: NSObject, ARSessionDelegate {
    var arVC: ARViewContainer
    let textRecognitionWorkQueue = DispatchQueue(label: "VisionRequest", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    @Binding var overlayText: String
    
    init(_ control: ARViewContainer, overlayText: Binding<String>) {
        self.arVC = control
        _overlayText = overlayText
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        if ready {
       
           
        }
        
    }
}


//MARK:- Custom Button SwiftUI
struct MyButtonStyle: ButtonStyle {
    var color: Color = .green
    
    public func makeBody(configuration: MyButtonStyle.Configuration) -> some View {
        
        configuration.label
            .foregroundColor(.white)
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 5).fill(color))
            .compositingGroup()
            .shadow(color: .black, radius: 3)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
    }
}

//MARK:- PencilKit SwiftUI
struct PKCanvasRepresentation : UIViewRepresentable {
    
    let canvasView = PKCanvasView()
    
    func makeUIView(context: Context) -> PKCanvasView {
        
        canvasView.tool = PKInkingTool(.pen, color: .secondarySystemBackground, width: 40)
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
    }
}

extension ARView{
   
     
    
    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tap)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        
        guard let touchInView = sender?.location(in: self) else {
            return
        }
        
        rayCastingMethod(point: touchInView)
        let entities = self.entities(at: touchInView)
        
    }
    
    func rayCastingMethod(point: CGPoint) {
        
        
        guard let coordinator = self.session.delegate as? ARViewCoordinator else{ return }

        guard let raycastQuery = self.makeRaycastQuery(from: point,
                                                       allowing: .existingPlaneInfinite,
                                                       alignment: .horizontal) else {
                                                        
                                                        print("failed first")
                                                        return
        }
        
        guard let result = self.session.raycast(raycastQuery).first else {
            print("failed")
            return
        }
        
        let transformation = Transform(matrix: result.worldTransform)
        let greenBox = CustomBox(color: .yellow)
        self.installGestures(.all, for: greenBox)
        greenBox.generateCollisionShapes(recursive: true)

        let mesh = MeshResource.generateText(
            "\(coordinator.overlayText)",
            extrusionDepth: 0.1,
            font: .systemFont(ofSize: 2),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail)
        
        let material = SimpleMaterial(color: .red, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(0.03, 0.03, 0.1)
        
        greenBox.addChild(entity)
        greenBox.transform = transformation
        //setting relative position...
        entity.setPosition(SIMD3<Float>(0, 0.05, 0), relativeTo: greenBox)
        let audioSource = SCNAudioSource(fileNamed: "pulse.mp3")!
        audioSource.loops = true
        // Decode the audio from disk ahead of time to prevent a delay in playback
        audioSource.load()
        
        let raycastAnchor = AnchorEntity(raycastResult: result)
        let audioFilePath = "pulse.mp3"
        raycastAnchor.addChild(greenBox)
        
        do {
          let resource = try AudioFileResource.load(named: audioFilePath, in: nil, inputMode: .spatial, loadingStrategy: .preload, shouldLoop: true)
          
          let audioController = entity.prepareAudio(resource)
          audioController.play()
         
          // If you want to start playing right away, you can replace lines 7-8 with line 11 below
          // let audioController = entity.playAudio(resource)
        } catch {
          print("Error loading audio file")
        }
        raycastAnchor.addChild(entity)
        self.scene.addAnchor(raycastAnchor)
    }
}
extension ARView: ARSessionDelegate {
    public func session(_ session: ARSession,
                       didUpdate frame: ARFrame) {
      
   }
}
extension ARView: ARCoachingOverlayViewDelegate {
    
    func addCoaching() {
        
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.delegate = self
        coachingOverlay.session = self.session
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let utterance = AVSpeechUtterance(string: "Move your device in a brightly lit area until I say stop")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        coachingOverlay.goal = .anyPlane
        self.addSubview(coachingOverlay)
    }
    
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        coachingOverlayView.activatesAutomatically = false
        //Ready to add objects
        let utterance = AVSpeechUtterance(string: "Stop")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
       // ready = true
    }
   
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif



var ready = false
