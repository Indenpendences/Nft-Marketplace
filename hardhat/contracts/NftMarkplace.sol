// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NoApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__PriceNotMet(
    address nftAddress,
    uint256 tokenId,
    uint256 price
);
error NftMarketplace__NoProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }

    // Nft contract address -> Nft TokenId -> Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    // seller address -> amount earned
    mapping(address => uint256) private s_proceeds;
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );
    event ItemCancel(
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId
    );

    ///////////////////
    ///  modifiers  ///
    ///////////////////
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NftMarketplace__NotOwner();
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];

        if (listing.price <= 0) {
            revert NftMarketplace__NotListed(nftAddress, tokenId);
            _;
        }
    }

    ///////////////////
    ///main function///
    ///////////////////

    /*
     * @notice Method for listing NFT
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param price sale price for each item
     */

    // 1. `listItem` : list nfts on the marketplace
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        // address tokenPayment // chainlink price feeds: nguồn cung cấp giá chainlink
        // challenge : have this contract accept payment in a subset of tokens as well
        // thách thức: hợp đồng này có chấp nhận thanh toán bằng một tập hợp con các mã thông báo hay không

        // hint : use chainlink price feeds to convert the price of the tokens between each other
        // // gợi ý: sử dụng nguồn cấp dữ liệu giá chainlink để chuyển đổi giá của các mã thông báo lẫn nhau
        notListed(nftAddress, tokenId, msg.sender)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }

        /* 1. send the nft to the contract. Tranfer -> Contract hold the Nft:
            gửi nft đến hợp đồng . chuyển  -> hợp đồng tổ chức
           2. owners can still hold their NFT, and give the marketplace approval to the sell the nft for them
            chủ sở hữu vẫn có thể giữ NFT của họ và cho phép thị trường chấp thuận bán nft cho họ.
        */
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace__NoApprovedForMarketplace();
        }

        // array mapping
        // mapping
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    // 2. `byteItem` : buy the nft
    function buyItem(address nftAddress, uint256 tokenId)
        external
        payable
        nonReentrant
        isListed(nftAddress, tokenId)
    {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert NftMarketplace__PriceNotMet(
                nftAddress,
                tokenId,
                listedItem.price
            );
        }
        IERC721(nftAddress).safeTransferFrom(
            listedItem.seller,
            msg.sender,
            tokenId
        );

        // we dont just send the seller the money ... ?

        // sending the money to the user
        // gửi tiền cho người dùng
        // have them withraw the money
        // để họ rút tiền
        s_proceeds[listedItem.seller] =
            s_proceeds[listedItem.seller] +
            msg.value;
        delete (s_listings[nftAddress][tokenId]);

        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
        // check to make sure the NFT was transfered
        // kiểm tra để đảm bảo NFT đã được chuyển
    }

    // 3. `cancelItem` : cancel the listing
    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId)
    {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCancel(msg.sender, nftAddress, tokenId);
    }

    // 4. `updateListing`: update price

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        isListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    // 5. `withrawProcessds`: Withdraw payment for my bought NFTs

    function withrawProcessds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NftMarketplace__NoProceeds();
        }

        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NftMarketplace__TransferFailed();
        }
    }

    ///////////////////
    //getter function//
    ///////////////////
    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}
