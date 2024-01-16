
import UIKit

protocol ItemDisplaying {
    var itemImageView: UIImageView! { get set }
    var titleLabel: UILabel! { get set }
    var detailLabel: UILabel! { get set }
}


class StoreItemCollectionViewController: UICollectionViewController {
    
    var collectionViewDataSource: UICollectionViewDiffableDataSource<String, StoreItem>!
    
    
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let itemSize =
        NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize =
        NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(0.5))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        section.interGroupSpacing = 8
        
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout(section: section)
    }
    
    func configureCollectionViewDataSource(_ collectionView:
       UICollectionView) {
        collectionViewDataSource =
           UICollectionViewDiffableDataSource<String, StoreItem>(collectionView: collectionView, cellProvider:
       { (collectionView, indexPath, item) -> UICollectionViewCell? in
            let cell =
               collectionView.dequeueReusableCell(withReuseIdentifier:
               "Item", for: indexPath) as! ItemCollectionViewCell

            self.collectionViewImageLoadTasks[indexPath]?.cancel()
            self.collectionViewImageLoadTasks[indexPath] = Task {
                cell.titleLabel.text = item.name
                cell.detailLabel.text = item.artist
                cell.itemImageView.image = UIImage(systemName: "photo")
                do {
                    let image = try await self.storeItemController.fetchImage(from: item.artworkURL)

                    cell.itemImageView.image = image
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // Ignore cancellation errors
                } catch {
                    cell.itemImageView.image = UIImage(systemName: "photo")
                    print("Error fetching image: \(error)")
                }
                self.collectionViewImageLoadTasks[indexPath] = nil
            }

            return cell
        })
    }
}
