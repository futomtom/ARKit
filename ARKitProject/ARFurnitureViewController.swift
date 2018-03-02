import ARKit
import Foundation
import SceneKit
import UIKit
import Photos
//import MIBlurPopup


extension UIStoryboard {
    class func AR() -> UIStoryboard {
        return UIStoryboard(name: "ARFurniture", bundle: nil)
    }
}


class InfoView:UIView {
    var blurView:UIVisualEffectView!
    var label:UILabel!
    var infoText:String? {
        didSet {
            label.text = infoText
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let blurEffect = UIBlurEffect(style: .light)
        blurView = UIVisualEffectView(effect: blurEffect)
        
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect:vibrancyEffect)
        blurView.contentView.addSubview(vibrancyView)
        
        blurView.layer.cornerRadius = 10
        blurView.layer.masksToBounds = true
        label = UILabel()
        label.text = "Scan the Floor"
        setLabelFont()
        label.textAlignment = .center
        blurView.contentView.addSubview(label)
        addSubview(blurView)
        
//        label.snp.makeConstraints { (make) in
//            make.width.height.equalTo(blurView)
//            make.center.equalTo(blurView)
//        }
    }
    
    func setLabelFont() {
         label.sizeToFit()
         label.textColor = .white
         label.font = UIFont(name: "Roboto-Bold", size: 14)
    }
    
    override func didMoveToSuperview() {
        guard let veiw = superview else {
            return
        }
//        blurView.snp.makeConstraints { (make) in
//            make.centerX.equalTo(veiw)
//            make.centerY.equalTo(veiw).offset(50)
//            make.height.equalTo(60)
//            make.width.equalTo(200)
//        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}

@available(iOS 11, *)
class ARFurnitureViewController: UIViewController {
    var dragOnInfinitePlanesEnabled = false
    var currentGesture: Gesture?
    
    var use3DOFTrackingFallback = false
    var screenCenter: CGPoint?
    
    let session = ARSession()
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    
    var trackingFallbackTimer: Timer?
    
    // Use average of recent virtual object distances to avoid rapid changes in object scale.
    var recentVirtualObjectDistances = [CGFloat]()
    var showDotPlane = true
    
    let DEFAULT_DISTANCE_CAMERA_TO_OBJECTS = Float(10)
    var virtualObject:VirtualObject?
    var infoView:InfoView!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var addObjectButton: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Ambient Light Estimation
    func toggleAmbientLightEstimation(_ enabled: Bool) {
        if enabled {
            if !sessionConfig.isLightEstimationEnabled {
                sessionConfig.isLightEstimationEnabled = true
                session.run(sessionConfig)
            }
        } else {
            if sessionConfig.isLightEstimationEnabled {
                sessionConfig.isLightEstimationEnabled = false
                session.run(sessionConfig)
            }
        }
    }
    
    // MARK: - Virtual Object Loading
    var isLoadingObject: Bool = false {
        didSet {
            DispatchQueue.main.async {
              
                self.addObjectButton.isEnabled = true
                self.deleteButton.isEnabled = !self.isLoadingObject
                self.restartExperienceButton.isEnabled = !self.isLoadingObject
            }
        }
    }
 
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        infoView = InfoView()
        view.addSubview(infoView)
        setupScene()
        setupFocusSquare()
        resetVirtualObject()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        restartPlaneDetection()
        showScanAnimation()
        
    }
    
    @IBAction func closeTapped(_ sender: UIButton) {
        
        
        dismiss(animated: false)
    }
    
    func showScanAnimation() {
        let image = UIImage(named: "handphone")
        let scanImageView = UIImageView(image: image)
        view.addSubview(scanImageView)
        let pt = CGPoint (x: view.center.x, y: view.center.y - 100 )
        scanImageView.center = pt
        
        CATransaction.begin ()
        CATransaction.setCompletionBlock ({
            DispatchQueue.main.async {
                scanImageView.removeFromSuperview()
                self.infoView.isHidden = true
            }
        })
        let animation = CABasicAnimation (keyPath: "position")
        animation.duration = 0.5
        animation.repeatCount = 2
        animation.autoreverses = true
        animation.fromValue = NSValue (cgPoint: CGPoint (x: pt.x - 50, y: pt.y))
        animation.toValue = NSValue (cgPoint: CGPoint (x: pt.x + 50, y: pt.y))
        animation.isRemovedOnCompletion = true
        scanImageView.layer.add (animation, forKey: "position")
        CATransaction.commit ()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    @IBAction func chooseObject(_ button: UIButton) {
        // Abort if we are about to load another object to avoid concurrent modifications of the scene.
        if isLoadingObject { return }
        
       // textManager.cancelScheduledMessage(forType: .contentPlacement)
        
        let vc = UIStoryboard.AR().instantiateViewController(withIdentifier: "VirtualObjectSelectionViewController") as! VirtualObjectSelectionViewController

        vc.delegate = self
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.delegate = self
        self.present(vc, animated: true, completion: nil)
        
        vc.popoverPresentationController?.sourceView = button
        vc.popoverPresentationController?.sourceRect = button.bounds
    }
    
    // MARK: - Planes
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let pos = SCNVector3.positionFromTransform(anchor.transform)
      //  textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
        
        let plane = Plane(anchor, showDotPlane)
        
        planes[anchor] = plane
        node.addChildNode(plane)
        
//        textManager.cancelScheduledMessage(forType: .planeEstimation)
//        textManager.showMessage("SURFACE DETECTED")
//        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
//            textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, ARMessageType: .contentPlacement)
//        }
    }
    
    func restartPlaneDetection() {
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
        
        // reset timer
        if trackingFallbackTimer != nil {
            trackingFallbackTimer!.invalidate()
            trackingFallbackTimer = nil
        }
        
     //   textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, ARMessageType: .planeEstimation)
    }
    
    // MARK: - Focus Square
    var focusSquare: FocusSquare?
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        sceneView.scene.rootNode.addChildNode(focusSquare!)
        
     //   textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, ARMessageType: .focusSquare)
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        
        let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected()
        if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
        }
        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
           
        }
    }

    
    // MARK: - Debug Visualizations
    
    @IBOutlet var featurePointCountLabel: UILabel!
    
    func refreshFeaturePoints() {
        
        
        guard let cloud = session.currentFrame?.rawFeaturePoints else {
            return
        }
        
       
    }
    
  
    
   
    
    // MARK: - UI Elements and Actions
    
  
    
 
    @IBOutlet weak var restartExperienceButton: UIButton!
    var restartExperienceButtonIsEnabled = true
    
    @IBAction func restartExperience(_ sender: Any) {
        guard restartExperienceButtonIsEnabled, !isLoadingObject else {
            return
        }
        
        DispatchQueue.main.async {
            self.restartExperienceButtonIsEnabled = false
            
       
           
            
            self.setupFocusSquare()
            //            self.loadVirtualObject()
            self.restartPlaneDetection()
            
            self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
            
            // Disable Restart button for five seconds in order to give the session enough time to restart.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                self.restartExperienceButtonIsEnabled = true
            })
        }
    }
    
 
    @IBAction func takeSnapShot() {
        var shareImage = sceneView.snapshot()
        AudioServicesPlaySystemSound(1108)  //camera shutter sound
        let vc = storyboard?.instantiateViewController(withIdentifier: "PopupViewController") as! PopupViewController
      
        vc.image = shareImage
//        MIBlurPopup.show(vc, on: self)
//        CustomAnalyticsEvent.logEventWithName(CustomEventName.ARScreenShotCaptured, customAttributes: nil)
    }
    
    // MARK: - Settings
    
   
    
    @IBAction func removeVirtualObject(_ button: UIButton) {
        guard virtualObject != nil else { return }
         virtualObject?.removeFromParentNode()
          virtualObject = nil
        
         DispatchQueue.main.async {
        UIView.animate(withDuration: 0.5, animations: {
            self.deleteButton.transform = CGAffineTransform(translationX: 0, y: 150)
            self.captureButton.transform = CGAffineTransform(translationX: 0, y: 150)
            self.addObjectButton.isHidden = false
        })
        }
        
        showDotPlane = true
    }
    
    @objc
    func dismissSettings() {
        self.dismiss(animated: true, completion: nil)
        
    }
    
  
    
    // MARK: - Error handling
    
  
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
            return
        }
        
        if currentGesture == nil {
            currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, object)
        } else {
            currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
        }
        
        displayVirtualObjectTransform()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            return
        }
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
        displayVirtualObjectTransform()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            chooseObject(addObjectButton)
            return
        }
        
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            return
        }
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
    }
}

// MARK: - ARKit / ARSCNView
@available(iOS 11, *)
extension ARFurnitureViewController {
    func setupScene() {
        sceneView.setUp(viewController: self, session: session)
        DispatchQueue.main.async {
            self.screenCenter = self.sceneView.bounds.mid
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
      //  textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable:
            break
         //   textManager.escalateFeedback(for: camera.trackingState, inSeconds: 5.0)
        case .limited:
            break
        case .normal:
         //   textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
            if use3DOFTrackingFallback && trackingFallbackTimer != nil {
                trackingFallbackTimer!.invalidate()
                trackingFallbackTimer = nil
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
     //   displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
//        textManager.blurBackground()
//        textManager.showAlert(title: "Session Interrupted",
//                              message: "The session will be reset after the interruption has ended.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
     //   textManager.unblurBackground()
        session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
        restartExperience(self)
     //   textManager.showMessage("RESETTING SESSION")
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
@available(iOS 11, *)
extension ARFurnitureViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        
    }
}

// MARK: - VirtualObjectSelectionViewControllerDelegate
@available(iOS 11, *)
extension ARFurnitureViewController :VirtualObjectSelectionViewControllerDelegate {
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, object: VirtualObject) {
        loadVirtualObject(object: object)
    }
    
    func loadVirtualObject(object: VirtualObject) {
        // Show progress indicator
//        let spinner = UIActivityIndicatorView()
//        spinner.center = addObjectButton.center
//        spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)
//
//        sceneView.addSubview(spinner)
//        spinner.startAnimating()
        
        DispatchQueue.global().async {
            self.isLoadingObject = true
            object.viewController = self
            VirtualObjectsManager.shared.addVirtualObject(virtualObject: object)
            VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: object)
            
            object.loadModel()
            
            DispatchQueue.main.async {
                if let lastFocusSquarePos = self.focusSquare?.lastPosition {
                    self.setNewVirtualObjectPosition(lastFocusSquarePos)
                   
                    UIView.animate(withDuration: 0.5, animations: {
                        self.deleteButton.transform = CGAffineTransform(translationX: 0, y: -150)
                        self.captureButton.transform = CGAffineTransform(translationX: 0, y: -150)
                     //   self.addObjectButton.isHidden = true
                    })
                   
                 
                } else {
                    self.setNewVirtualObjectPosition(SCNVector3Zero)
                }
                self.isLoadingObject = false
            }
        }
    }
}

// MARK: - ARSCNViewDelegate
@available(iOS 11, *)
extension ARFurnitureViewController :ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        refreshFeaturePoints()
        
        DispatchQueue.main.async {
            self.updateFocusSquare()
            // If light estimation is enabled, update the intensity of the model's lights and the environment map
            if let lightEstimate = self.session.currentFrame?.lightEstimate {
                self.sceneView.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
            } else {
                self.sceneView.enableEnvironmentMapWithIntensity(25)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("didAdd")
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.addPlane(node: node, anchor: planeAnchor)
                self.addObjectButton.isHidden = false
             
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                if let plane = self.planes[planeAnchor] {
                    plane.update(planeAnchor, self.showDotPlane)
                }
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor, let plane = self.planes.removeValue(forKey: planeAnchor) {
                plane.removeFromParentNode()
            }
        }
    }
}

// MARK: Virtual Object Manipulation
@available(iOS 11, *)
extension ARFurnitureViewController {
    func displayVirtualObjectTransform() {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
            let cameraTransform = session.currentFrame?.camera.transform else {
                return
        }
        
        // Output the current translation, rotation & scale of the virtual object as text.
        let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
        let vectorToCamera = cameraPos - object.position
        
        let distanceToUser = vectorToCamera.length()
        
        var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        let distance = String(format: "%.2f", distanceToUser)
        let scale = String(format: "%.2f", object.scale.x)
      //  textManager.showDebugMessage("Distance: \(distance) m\nRotation: \(angleDegrees)°\nScale: \(scale)x")
    }
    
    func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {
        
        guard let newPosition = pos else {
          //  textManager.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
            // Reset the content selection in the menu only if the content has not yet been initially placed.
            if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
                resetVirtualObject()
            }
            return
        }
        
        if instantly {
            setNewVirtualObjectPosition(newPosition)
        } else {
            updateVirtualObjectPosition(newPosition, filterPosition)
        }
    }
    
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?,
        planeAnchor: ARPlaneAnchor?,
        hitAPlane: Bool) {
            
            // -------------------------------------------------------------------------------
            // 1. Always do a hit test against exisiting plane anchors first.
            //    (If any such anchors exist & only within their extents.)
            
            let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
            if let result = planeHitTestResults.first {
                
                let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
                let planeAnchor = result.anchor
                
                // Return immediately - this is the best possible outcome.
                return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
            }
            
            // -------------------------------------------------------------------------------
            // 2. Collect more information about the environment by hit testing against
            //    the feature point cloud, but do not return the result yet.
            
            var featureHitTestPosition: SCNVector3?
            var highQualityFeatureHitTestResult = false
            
            let highQualityfeatureHitTestResults =
                sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
            
            if !highQualityfeatureHitTestResults.isEmpty {
                let result = highQualityfeatureHitTestResults[0]
                featureHitTestPosition = result.position
                highQualityFeatureHitTestResult = true
            }
            
            // -------------------------------------------------------------------------------
            // 3. If desired or necessary (no good feature hit test result): Hit test
            //    against an infinite, horizontal plane (ignoring the real world).
            
            if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
                
                let pointOnPlane = objectPos ?? SCNVector3Zero
                
                let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
                if pointOnInfinitePlane != nil {
                    return (pointOnInfinitePlane, nil, true)
                }
            }
            
            // -------------------------------------------------------------------------------
            // 4. If available, return the result of the hit test against high quality
            //    features if the hit tests against infinite planes were skipped or no
            //    infinite plane was hit.
            
            if highQualityFeatureHitTestResult {
                return (featureHitTestPosition, nil, false)
            }
            
            // -------------------------------------------------------------------------------
            // 5. As a last resort, perform a second, unfiltered hit test against features.
            //    If there are no features in the scene, the result returned here will be nil.
            
            let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
            if !unfilteredFeatureHitTestResults.isEmpty {
                let result = unfilteredFeatureHitTestResults[0]
                return (result.position, nil, false)
            }
            
            return (nil, nil, false)
    }
    
    func setNewVirtualObjectPosition(_ pos: SCNVector3) {
        
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
            let cameraTransform = session.currentFrame?.camera.transform else {
                return
        }
        
        recentVirtualObjectDistances.removeAll()
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)
        
        object.position = cameraWorldPos + cameraToPosition
        
        object.scale = SCNVector3(0.1,0.1,0.1)
        object.runAction(SCNAction.scale(to: 1, duration: 0.2))
        virtualObject = object
        
        if object.parent == nil {
            sceneView.scene.rootNode.addChildNode(object)
            showDotPlane = false
        }
        
    }
    
    func resetVirtualObject() {
        VirtualObjectsManager.shared.resetVirtualObjects()
        showDotPlane = true
       //  addObjectButton.setImage(#imageLiteral(resourceName: "addBtn"), for: [])
      
    }
    
    func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
            return
        }
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)
        
        // Compute the average distance of the object from the camera over the last ten
        // updates. If filterPosition is true, compute a new position for the object
        // with this average. Notice that the distance is applied to the vector from
        // the camera to the content, so it only affects the percieved distance of the
        // object - the averaging does _not_ make the content "lag".
        let hitTestResultDistance = CGFloat(cameraToPosition.length())
        
        recentVirtualObjectDistances.append(hitTestResultDistance)
        recentVirtualObjectDistances.keepLast(10)
        
        if filterPosition {
            let averageDistance = recentVirtualObjectDistances.average!
            
            cameraToPosition.setLength(Float(averageDistance))
            let averagedDistancePos = cameraWorldPos + cameraToPosition
            
            object.position = averagedDistancePos
        } else {
            object.position = cameraWorldPos + cameraToPosition
        }
    }
    
    func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
            let planeAnchorNode = sceneView.node(for: anchor) else {
                return
        }
        
        // Get the object's position in the plane's coordinate system.
        let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
        
        if objectPos.y == 0 {
            return; // The object is already on the plane
        }
        
        // Add 10% tolerance to the corners of the plane.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
            return
        }
        
        // Drop the object onto the plane if it is near it.
        let verticalAllowance: Float = 0.03
        if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
          //  textManager.showDebugMessage("OBJECT MOVED\nSurface detected nearby")
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            object.position.y = anchor.transform.columns.3.y
            SCNTransaction.commit()
        }
    }
}
