// Extract data for calculations
const views = Number($json.items[0].statistics.viewCount || 0);
const likes = Number($json.items[0].statistics.likeCount || 0);
const comments = Number($json.items[0].statistics.commentCount || 0);

// Calculate ratios
const likeRatio = views > 0 ? (likes / views) * 100 : 0;
const commentRatio = views > 0 ? (comments / views) * 100 : 0;

// Extract title and video ID
const title = $json.items[0].snippet.title || "";
const videoId = $json.items[0].id || "";
const youtubeUrl = `https://www.youtube.com/watch?v=${videoId}`;

// Return only the essential data
return {
    title,
    youtubeUrl,
    likeRatio,
    commentRatio
};