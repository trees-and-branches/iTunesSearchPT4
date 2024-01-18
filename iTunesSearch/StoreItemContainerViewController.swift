
import UIKit

class StoreItemContainerViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet var tableContainerView: UIView!
    @IBOutlet var collectionContainerView: UIView!
    
    let searchController = UISearchController()
    let storeItemController = StoreItemController()
    
    var items = [StoreItem]()
    
    var itemsSnapshot: NSDiffableDataSourceSnapshot<String, StoreItem> {
        var snapshot = NSDiffableDataSourceSnapshot<String, StoreItem>()
        
        snapshot.appendSections(["Results"])
        snapshot.appendItems(items)
        
        return snapshot
    }

    let queryOptions = ["movie", "music", "software", "ebook"]
    
    // keep track of async tasks so they can be cancelled if appropriate.
    var searchTask: Task<Void, Never>? = nil
    var tableViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    var collectionViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    
    var tableViewDataSource: UITableViewDiffableDataSource<String, StoreItem>!
    var collectionViewDataSource: UICollectionViewDiffableDataSource<String, StoreItem>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        

        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.automaticallyShowsSearchResultsController = true
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = ["Movies", "Music", "Apps", "Books"]
    }
    
    func configureTableViewDataSource(_ tableView: UITableView) {
        tableViewDataSource = UITableViewDiffableDataSource<String,
           StoreItem>(tableView: tableView, cellProvider: { (tableView,
           indexPath, item) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier:
               "Item", for: indexPath) as! ItemTableViewCell
               
            self.tableViewImageLoadTasks[indexPath]?.cancel()
            self.tableViewImageLoadTasks[indexPath] = Task {
                cell.titleLabel.text = item.name
                cell.detailLabel.text = item.artist
                cell.itemImageView.image = UIImage(systemName: "photo")
                do {
                    let image = try await
                       self.storeItemController.fetchImage(from:
                          item.artworkURL)
                    
                    cell.itemImageView.image = image
                } catch let error as NSError where error.domain ==
                   NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // Ignore cancellation errors
                } catch {
                    cell.itemImageView.image = UIImage(systemName:
                       "photo")
                    print("Error fetching image: \(error)")
                }
                self.tableViewImageLoadTasks[indexPath] = nil
            }
               
            return cell
        })
    }
    
    func configureCollectionViewDataSource(_ collectionView:
                                           UICollectionView) {
        collectionViewDataSource =
        UICollectionViewDiffableDataSource<String, StoreItem>(collectionView: collectionView, cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Item", for: indexPath) as! ItemCollectionViewCell
            
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
    
    func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fetchMatchingItems), object: nil)
        perform(#selector(fetchMatchingItems), with: nil, afterDelay: 0.3)
    }
                
    @IBAction func switchContainerView(_ sender: UISegmentedControl) {
        tableContainerView.isHidden.toggle()
        collectionContainerView.isHidden.toggle()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tableViewController = segue.destination as? StoreItemListTableViewController {
            configureTableViewDataSource(tableViewController.tableView)
        }
        if let collectionViewController = segue.destination as? StoreItemCollectionViewController {
            configureCollectionViewDataSource(collectionViewController.collectionView)
        }
    }
    
    @objc func fetchMatchingItems() {
        
        self.items = []
                
        let searchTerm = searchController.searchBar.text ?? ""
        let mediaType = queryOptions[searchController.searchBar.selectedScopeButtonIndex]
        
        // cancel existing task since we will not use the result
        // Cancel any images that are still being fetched and reset the imageTask dictionaries​ 
        collectionViewImageLoadTasks.values.forEach { task in task.cancel() }
        collectionViewImageLoadTasks = [:]
        tableViewImageLoadTasks.values.forEach { task in task.cancel() }
        tableViewImageLoadTasks = [:]
        
        
        searchTask?.cancel()
        searchTask = Task {
            if !searchTerm.isEmpty {
                
                // set up query dictionary
                let query = [
                    "term": searchTerm,
                    "media": mediaType,
                    "lang": "en_us",
                    "limit": "20"
                ]
                
                // use the item controller to fetch items
                do {
                    // use the item controller to fetch items
                    let items = try await storeItemController.fetchItems(matching: query)
                    if searchTerm == self.searchController.searchBar.text &&
                          mediaType == queryOptions[searchController.searchBar.selectedScopeButtonIndex] {
                        self.items = items
                    }
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // ignore cancellation errors
                } catch {
                    // otherwise, print an error to the console
                    print(error)
                }
                await tableViewDataSource.apply(itemsSnapshot)
                await collectionViewDataSource.apply(itemsSnapshot, animatingDifferences: true)
            } else {
                
                await tableViewDataSource.apply(itemsSnapshot)
                await collectionViewDataSource.apply(itemsSnapshot, animatingDifferences: true)
                
            }
            searchTask = nil
        }
    }
    
}

extension StoreItemContainerViewController {
    
    func generateGridLayout() -> UICollectionViewLayout {
        let padding: CGFloat = 20
        
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1)), subitem: item, count: 2)
        
        group.interItemSpacing = .fixed(padding)
        
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: padding, bottom: 0, trailing: padding)
        
        let section = NSCollectionLayoutSection(group: group)
        
        section.interGroupSpacing = padding
        
        section.contentInsets = NSDirectionalEdgeInsets(top: padding, leading: 0, bottom: padding, trailing: 0)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
}
