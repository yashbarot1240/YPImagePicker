//
//  YPFilterVideoCollectionViewCell.swift
//  YPImagePicker
//
//  Created by Kunj Mac3 on 27/09/18.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit

class YPFilterVideoCollectionViewCell: UICollectionViewCell {

    @IBOutlet var imageView: UIImageView!
    
    @IBOutlet var name: UILabel!
    
    override var isHighlighted: Bool { didSet {
        UIView.animate(withDuration: 0.1) {
            self.contentView.transform = self.isHighlighted
                ? CGAffineTransform(scaleX: 0.95, y: 0.95)
                : CGAffineTransform.identity
        }
        }
    }
    override var isSelected: Bool { didSet {
        name.textColor = isSelected
            ? UIColor(r: 38, g: 38, b: 38)
            : UIColor(r: 154, g: 154, b: 154)
        
        name.font = .systemFont(ofSize: 11, weight: isSelected
            ? UIFont.Weight.medium
            : UIFont.Weight.regular)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        name.font = .systemFont(ofSize: 11, weight: UIFont.Weight.regular)
        name.textColor = UIColor(r: 154, g: 154, b: 154)
        name.textAlignment = .center
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        self.clipsToBounds = false
        self.layer.shadowColor = UIColor(r: 46, g: 43, b: 37).cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = CGSize(width: 4, height: 7)
        self.layer.shadowRadius = 5
        self.layer.backgroundColor = UIColor.clear.cgColor
    }

}
