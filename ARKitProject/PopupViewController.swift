//
//  PopupViewController.swift
//  MIBlurPopup
//
//  Created by Mario on 14/01/2017.
//  Copyright © 2017 Mario. All rights reserved.
//

import UIKit
//import MIBlurPopup

protocol PopupViewControllerDelegate: class {
    func setAsBackground()
}

class PopupViewController: UIViewController {
    var image:UIImage!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var msgLabel: UILabel!
    @IBOutlet weak var popContainerView: UIView!

    @IBOutlet weak var shareButton: UIButton!
    weak var delegate:PopupViewControllerDelegate?
    // MARK: - IBOutlets
    
    @IBOutlet weak var yesButton: UIButton! {
        didSet {
            yesButton.layer.cornerRadius = yesButton.frame.height/2
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBOutlet weak var popupContentContainerView: UIView!
   

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
        popContainerView.layer.cornerRadius = 20
        popContainerView.clipsToBounds = true
        modalPresentationCapturesStatusBarAppearance = true
        
       // shareButton.isHidden = DeviceType.IS_IPAD ? true:false 
    }
    
    // MARK: - IBActions
    
    @IBAction func dismissButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func shareButtonTapped(_ sender: UIButton) {
        if let jpgImage = UIImageJPEGRepresentation(image, 0.6) {
            let activity = UIActivityViewController(activityItems: [jpgImage], applicationActivities: [])
            activity.excludedActivityTypes = [.airDrop, .addToReadingList, .openInIBooks, .print, .assignToContact]
            present(activity, animated: true)
        }

    }

    @IBAction func yesButtonTapped(_ sender: UIButton) {
        delegate?.setAsBackground()

    }


}

// MARK: - MIBlurPopupDelegate

//extension PopupViewController: MIBlurPopupDelegate {
//
//    var popupView: UIView {
//        return popupContentContainerView ?? UIView()
//    }
//
//    var blurEffectStyle: UIBlurEffectStyle {
//        return .dark
//    }
//
//    var initialScaleAmmount: CGFloat {
//        return 0.7
//    }
//
//    var animationDuration: TimeInterval {
//        return 0.5
//    }
//
//}

