//
//  PagingOriginInfo.swift
//  MGArchitecture
//
//  Created by truong.tuan.quang on 11/21/18.
//  Copyright © 2018 Framgia. All rights reserved.
//

import Foundation

public struct PagingOriginInfo<T> {
    public let page: Int
    public let items: [T]
    
    public init(page: Int, items: [T]) {
        self.page = page
        self.items = items
    }
}
