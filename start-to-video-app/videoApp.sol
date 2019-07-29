pragma solidity ^0.5.9;
pragma experimental ABIEncoderV2;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

contract VideoApp {
    using SafeMath for uint256;
    
    struct Video{
        uint256 id;
        string name;
        string[][] chunksOfContent;
        uint256 segmentCount;
        uint256 timestamp;
    }
    
    struct VideoSegment{
        uint256 segmentId;
        uint256 ofSegmentId;
        string segmentContent;
    }
    
    struct PartialVideo{
        uint256 id;
        string name;
        string[] content;
        uint256 segmentsIndex;
        uint256 segmentTotalCount;
        uint256 timestamp;
    }
    
    Video[] videos;
    mapping(uint256 => address) private videoIdToOwner;
    mapping(string => uint256) private videoNameToIndex;
    mapping(address => uint256[]) private ownersVideoIndexes;
    mapping(string => bool) private videoExists;
    
    uint256 MAX_SEGMENT_SIZE = 2000;
   
    event VideoAdded();
    
    constructor() public{}
    
    function AddNewVideo(string memory name, string[] memory segments) public returns(bool){
        require(segments.length > 0);
        //Create segments
        Video memory video = _chunkSegments(name, segments);
        //Setup mappings
        _setupAdditionMappings(video);
        return true;
    }
    
    function _chunkSegments(string memory name, string[] memory segments) internal returns(Video memory){
        uint256 chunkCount = _getChunkCount( segments.length);
        string[][] memory chunksOfSegments = new string[][](chunkCount);
        string[] memory segmentsToAdd = new string[](MAX_SEGMENT_SIZE);
        uint256 currentChunkCount = 0;
        uint256 runningChunkNum = 0;
        for(uint256 i=0;i<segments.length;i++){
            segmentsToAdd[i] = segments[i];
            runningChunkNum = i.div(MAX_SEGMENT_SIZE);
            if(runningChunkNum > currentChunkCount){
                chunksOfSegments[currentChunkCount] = segmentsToAdd;
                segmentsToAdd = new string[](MAX_SEGMENT_SIZE);
                currentChunkCount = runningChunkNum;
            }
        }
        //Add video
        uint256 id = videos.length;
        return Video(id, name, chunksOfSegments, chunksOfSegments.length, now);
    }
    
    function _setupAdditionMappings(Video memory video) internal{
        videos.push(video);
        videoExists[video.name] = true;
        videoNameToIndex[video.name] = video.id;
        videoIdToOwner[video.id] = msg.sender;
        ownersVideoIndexes[msg.sender].push(video.id);
    }
    
     function _getChunkCount(uint256 segmentsLength) internal returns(uint256){
        uint256 chunkCount = segmentsLength.div(MAX_SEGMENT_SIZE);
        if(segmentsLength.mod(MAX_SEGMENT_SIZE) > 0){
            chunkCount = chunkCount.add(1);
        }
        return chunkCount;
    }
        
    function GetVideoSegments(string memory name, uint256 currentSegementId) public returns(PartialVideo memory){
        require(videoExists[name] == true);
        //Get video
        uint256 indexOfVideo = videoNameToIndex[name];
        Video memory video = videos[indexOfVideo];
        //Get chunk to return
        string[] memory chunkOfSegments = video.chunksOfContent[currentSegementId];
        return PartialVideo(video.id, video.name, chunkOfSegments, currentSegementId, video.chunksOfContent.length, video.timestamp);
    }
    
    function doesVideoNameExist(string memory name) public returns(bool){
        return videoExists[name];
    }
    
    function getOwnersVideoIndexes(address owner) public returns(uint256[] memory){
        return ownersVideoIndexes[owner];
    }
    
}
