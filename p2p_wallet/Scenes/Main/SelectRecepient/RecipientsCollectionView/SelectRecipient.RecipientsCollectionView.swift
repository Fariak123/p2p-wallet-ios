//
//  SelectRecipient.RecipientsCollectionView.swift
//  p2p_wallet
//
//  Created by Chung Tran on 27/10/2021.
//

import Foundation
import BECollectionView

extension SelectRecipient {
    final class RecipientsCollectionView: BEStaticSectionsCollectionView {
        // MARK: - Dependencies
        private let recipientsListViewModel: RecipientsListViewModel
        
        // MARK: - Initializer
        init(recipientsListViewModel: RecipientsListViewModel) {
            self.recipientsListViewModel = recipientsListViewModel
            
            let section: BEStaticSectionsCollectionView.Section = .init(
                index: 0,
                layout: .init(
                    header: .init(viewClass: SectionHeaderView.self, heightDimension: .absolute(76)),
                    cellType: RecipientCell.self,
                    numberOfLoadingCells: 2
                ),
                viewModel: recipientsListViewModel
            )
            
            super.init(
                header: nil,
                sections: [section],
                footer: nil
            )
        }
        
        // MARK: -
        
        /// Do anything after a snapshot of data has been loaded (update header for example)
        override func dataDidLoad() {
            super.dataDidLoad()
//            let header = sectionHeaderView(sectionIndex: 0) as? SectionHeaderView {
//                // do something with header
//            }
        }
    }
}
