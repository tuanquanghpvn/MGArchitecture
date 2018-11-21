import RxSwift
import RxCocoa
import OrderedSet

extension ViewModelType {
    public func setupLoadMorePagingOrigin<T>(loadTrigger: Driver<Void>,
                                       getItems: @escaping () -> Observable<PagingOriginInfo<T>>,
                                       refreshTrigger: Driver<Void>,
                                       refreshItems: @escaping () -> Observable<PagingOriginInfo<T>>,
                                       loadMoreTrigger: Driver<Void>,
                                       loadMoreItems: @escaping (Int) -> Observable<PagingOriginInfo<T>>)
        ->
        (page: BehaviorRelay<PagingOriginInfo<T>>,
        fetchItems: Driver<Void>,
        error: Driver<Error>,
        loading: Driver<Bool>,
        refreshing: Driver<Bool>,
        loadingMore: Driver<Bool>) {
            
            return setupLoadMorePagingOriginWithParam(
                loadTrigger: loadTrigger,
                getItems: { _ in
                    return getItems()
                },
                refreshTrigger: refreshTrigger,
                refreshItems: { _ in
                    return refreshItems()
                },
                loadMoreTrigger: loadMoreTrigger,
                loadMoreItems: { _, page in
                    return loadMoreItems(page)
                })
    }
    
    public func setupLoadMorePagingOrigin<T, V>(loadTrigger: Driver<Void>,
                                          getItems: @escaping () -> Observable<PagingOriginInfo<T>>,
                                          refreshTrigger: Driver<Void>,
                                          refreshItems: @escaping () -> Observable<PagingOriginInfo<T>>,
                                          loadMoreTrigger: Driver<Void>,
                                          loadMoreItems: @escaping (Int) -> Observable<PagingOriginInfo<T>>,
                                          mapper: @escaping (T) -> V)
        ->
        (page: BehaviorRelay<PagingOriginInfo<V>>,
        fetchItems: Driver<Void>,
        error: Driver<Error>,
        loading: Driver<Bool>,
        refreshing: Driver<Bool>,
        loadingMore: Driver<Bool>) {
            
            return setupLoadMorePagingOriginWithParam(
                loadTrigger: loadTrigger,
                getItems: { _ in
                    return getItems()
                },
                refreshTrigger: refreshTrigger,
                refreshItems: { _ in
                    return refreshItems()
                },
                loadMoreTrigger: loadMoreTrigger,
                loadMoreItems: { _, page in
                    return loadMoreItems(page)
                },
                mapper: mapper)
    }
}

extension ViewModelType {
    public func setupLoadMorePagingOriginWithParam<T, U>(loadTrigger: Driver<U>,
                                                   getItems: @escaping (U) -> Observable<PagingOriginInfo<T>>,
                                                   refreshTrigger: Driver<U>,
                                                   refreshItems: @escaping (U) -> Observable<PagingOriginInfo<T>>,
                                                   loadMoreTrigger: Driver<U>,
                                                   loadMoreItems: @escaping (U, Int) -> Observable<PagingOriginInfo<T>>)
        ->
        (page: BehaviorRelay<PagingOriginInfo<T>>,
        fetchItems: Driver<Void>,
        error: Driver<Error>,
        loading: Driver<Bool>,
        refreshing: Driver<Bool>,
        loadingMore: Driver<Bool>) {
            
            let pageSubject = BehaviorRelay<PagingOriginInfo<T>>(value: PagingOriginInfo<T>(page: 1, items: []))
            let errorTracker = ErrorTracker()
            let loadingActivityIndicator = ActivityIndicator()
            let refreshingActivityIndicator = ActivityIndicator()
            let loadingMoreActivityIndicator = ActivityIndicator()
            
            let loading = loadingActivityIndicator.asDriver()
            let refreshing = refreshingActivityIndicator.asDriver()
            let loadingMoreSubject = PublishSubject<Bool>()
            let loadingMore = Driver.merge(loadingMoreActivityIndicator.asDriver(),
                                           loadingMoreSubject.asDriverOnErrorJustComplete())
            
            let loadingOrLoadingMore = Driver.merge(loading, refreshing, loadingMore)
                .startWith(false)
            
            let loadItems = loadTrigger
                .withLatestFrom(loadingOrLoadingMore) {
                    (arg: $0, loading: $1)
                }
                .filter { !$0.loading }
                .map { $0.arg }
                .flatMapLatest { arg in
                    getItems(arg)
                        .trackError(errorTracker)
                        .trackActivity(loadingActivityIndicator)
                        .asDriverOnErrorJustComplete()
                }
                .do(onNext: { page in
                    pageSubject.accept(page)
                })
                .mapToVoid()
            
            let refreshItems = refreshTrigger
                .withLatestFrom(loadingOrLoadingMore) {
                    (arg: $0, loading: $1)
                }
                .filter { !$0.loading }
                .map { $0.arg }
                .flatMapLatest { arg in
                    refreshItems(arg)
                        .trackError(errorTracker)
                        .trackActivity(refreshingActivityIndicator)
                        .asDriverOnErrorJustComplete()
                }
                .do(onNext: { page in
                    pageSubject.accept(page)
                })
                .mapToVoid()
            
            let loadMoreItems = loadMoreTrigger
                .withLatestFrom(loadingOrLoadingMore) {
                    (arg: $0, loading: $1)
                }
                .filter { !$0.loading }
                .map { $0.arg }
                .withLatestFrom(pageSubject.asDriverOnErrorJustComplete()) { arg, page in
                    (arg, page)
                }
                .do(onNext: { _, page in
                    if page.items.isEmpty {
                        loadingMoreSubject.onNext(false)
                    }
                })
                .map { $0.0 }
                .filter { _ in !pageSubject.value.items.isEmpty }
                .flatMapLatest { arg -> Driver<PagingOriginInfo<T>> in
                    let page = pageSubject.value.page
                    return loadMoreItems(arg, page + 1)
                        .trackError(errorTracker)
                        .trackActivity(loadingMoreActivityIndicator)
                        .asDriverOnErrorJustComplete()
                }
                .filter { !$0.items.isEmpty }
                .do(onNext: { page in
                    let currentPage = pageSubject.value
                    let items: [T] = currentPage.items + page.items
                    let newPage = PagingOriginInfo<T>(page: page.page, items: items)
                    pageSubject.accept(newPage)
                })
                .mapToVoid()
            
            let fetchItems = Driver.merge(loadItems, refreshItems, loadMoreItems)
            return (pageSubject,
                    fetchItems,
                    errorTracker.asDriver(),
                    loading,
                    refreshing,
                    loadingMore)
    }
    
    public func setupLoadMorePagingOriginWithParam<T, U, V>(loadTrigger: Driver<U>,
                                                      getItems: @escaping (U) -> Observable<PagingOriginInfo<T>>,
                                                      refreshTrigger: Driver<U>,
                                                      refreshItems: @escaping (U) -> Observable<PagingOriginInfo<T>>,
                                                      loadMoreTrigger: Driver<U>,
                                                      loadMoreItems: @escaping (U, Int) -> Observable<PagingOriginInfo<T>>,
                                                      mapper: @escaping (T) -> V)
        ->
        (page: BehaviorRelay<PagingOriginInfo<V>>,
        fetchItems: Driver<Void>,
        error: Driver<Error>,
        loading: Driver<Bool>,
        refreshing: Driver<Bool>,
        loadingMore: Driver<Bool>) {
            
            let pageSubject = BehaviorRelay<PagingOriginInfo<V>>(value: PagingOriginInfo<V>(page: 1, items: []))
            let errorTracker = ErrorTracker()
            let loadingActivityIndicator = ActivityIndicator()
            let refreshingActivityIndicator = ActivityIndicator()
            let loadingMoreActivityIndicator = ActivityIndicator()
            
            let loading = loadingActivityIndicator.asDriver()
            let refreshing = refreshingActivityIndicator.asDriver()
            let loadingMoreSubject = PublishSubject<Bool>()
            let loadingMore = Driver.merge(loadingMoreActivityIndicator.asDriver(),
                                           loadingMoreSubject.asDriverOnErrorJustComplete())
            
            let loadingOrLoadingMore = Driver.merge(loading, refreshing, loadingMore)
                .startWith(false)
            
            let loadItems = loadTrigger
                .withLatestFrom(loadingOrLoadingMore) {
                    (arg: $0, loading: $1)
                }
                .filter { !$0.loading }
                .map { $0.arg }
                .flatMapLatest { arg in
                    getItems(arg)
                        .trackError(errorTracker)
                        .trackActivity(loadingActivityIndicator)
                        .asDriverOnErrorJustComplete()
                }
                .do(onNext: { page in
                    let newPage = PagingOriginInfo<V>(page: page.page,
                                                items: page.items.map(mapper))
                    pageSubject.accept(newPage)
                })
                .mapToVoid()
            
            let refreshItems = refreshTrigger
                .withLatestFrom(loadingOrLoadingMore) {
                    (arg: $0, loading: $1)
                }
                .filter { !$0.loading }
                .map { $0.arg }
                .flatMapLatest { arg in
                    refreshItems(arg)
                        .trackError(errorTracker)
                        .trackActivity(refreshingActivityIndicator)
                        .asDriverOnErrorJustComplete()
                }
                .do(onNext: { page in
                    let newPage = PagingOriginInfo<V>(page: page.page,
                                                items: page.items.map(mapper))
                    pageSubject.accept(newPage)
                })
                .mapToVoid()
            
            let loadMoreItems = loadMoreTrigger
                .withLatestFrom(loadingOrLoadingMore) {
                    (arg: $0, loading: $1)
                }
                .filter { !$0.loading }
                .map { $0.arg }
                .withLatestFrom(pageSubject.asDriverOnErrorJustComplete()) { arg, page in
                    (arg, page)
                }
                .do(onNext: { _, page in
                    if page.items.isEmpty {
                        loadingMoreSubject.onNext(false)
                    }
                })
                .map { $0.0 }
                .filter { _ in !pageSubject.value.items.isEmpty }
                .flatMapLatest { arg -> Driver<PagingOriginInfo<T>> in
                    let page = pageSubject.value.page
                    return loadMoreItems(arg, page + 1)
                        .trackError(errorTracker)
                        .trackActivity(loadingMoreActivityIndicator)
                        .asDriverOnErrorJustComplete()
                }
                .filter { !$0.items.isEmpty }
                .do(onNext: { page in
                    let currentPage = pageSubject.value
                    let items: [V] = currentPage.items + page.items.map(mapper)
                    let newPage = PagingOriginInfo<V>(page: page.page, items: items)
                    pageSubject.accept(newPage)
                })
                .mapToVoid()
            
            let fetchItems = Driver.merge(loadItems, refreshItems, loadMoreItems)
            return (pageSubject,
                    fetchItems,
                    errorTracker.asDriver(),
                    loading,
                    refreshing,
                    loadingMore)
    }
}
