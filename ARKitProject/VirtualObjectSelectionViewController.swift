import UIKit

class ARCell:UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    
}


@available(iOS 11, *)
class VirtualObjectSelectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    @IBOutlet weak var collectionView: UICollectionView!
	private var size: CGSize!
	weak var delegate: VirtualObjectSelectionViewControllerDelegate?


	override func viewDidLoad() {
		super.viewDidLoad()

      
        
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        collectionView.showsHorizontalScrollIndicator = false
    

		self.preferredContentSize = CGSize(width: view.frame.width - 40 , height: 150)

		self.view.addSubview(collectionView)
	}

    func getObject(index: Int) -> VirtualObject {
        switch index {
        case 0:
            return VirtualObject(modelName: "woodtable", fileExtension: "scn", thumbImageFilename: "woodtable.jpg", title: "Lamp")
        case 1:
            return VirtualObject(modelName: "tvstand", fileExtension: "scn", thumbImageFilename: "tvstand.jpg", title: "candle")
        case 2:
            return VirtualObject(modelName: "sofa", fileExtension: "scn", thumbImageFilename: "sofa.jpg", title: "chair")
        case 3:
            return VirtualObject(modelName: "vase", fileExtension: "scn", thumbImageFilename: "vase.jpg", title: "vase")
        case 4:
            return VirtualObject(modelName: "woodchair", fileExtension: "scn", thumbImageFilename: "woodtable.jpg", title: "vase")
        default:
            return VirtualObject(modelName: "chair", fileExtension: "scn", thumbImageFilename: "chair.jpg", title: "chair")
        }
    }

	static let COUNT_OBJECTS = 5
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return VirtualObjectSelectionViewController.COUNT_OBJECTS
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
         let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ARCell", for: indexPath) as! ARCell
      
        
        // Fill up the cell with data from the object.
        let object = getObject(index: indexPath.row)
        cell.imageView.image = object.thumbImage!

        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.virtualObjectSelectionViewController(self, object: getObject(index: indexPath.row))
        self.dismiss(animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        cell?.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        cell?.backgroundColor = UIColor.clear
    }
}

// MARK: - VirtualObjectSelectionViewControllerDelegate
@available(iOS 11, *)
protocol VirtualObjectSelectionViewControllerDelegate: class {
	func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, object: VirtualObject)
}
