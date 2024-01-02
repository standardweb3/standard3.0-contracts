

interface IBond {
    function initialize(
        uint256 id_,
        address collateral_,
        address debt_,
        address market_
    ) external;
    
    function liquidate() external;

    function withdrawCollateral(uint256 amount) external;
}