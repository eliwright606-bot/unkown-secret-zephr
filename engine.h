#import <Foundation/Foundation.h>

typedef struct EngineLine {
    char move[8];
    bool hasScore;
    bool isMate;
    int  score;
} EngineLine;

typedef void (^EngineResultBlock)(const EngineLine *lines, int count);

#ifdef __cplusplus
extern "C" {
#endif

void EngineStart(void);

// depth drives a movetime budget for Midnight (it has no "go depth");
// elo and multipv are accepted for API compatibility and ignored
void EngineGo(const char *fen, int depth, int elo, int multipv, EngineResultBlock done);

int EngineLegalMoves(const char *fen, char *out, int maxMoves);

bool EngineFenLegal(const char *fen);

#ifdef __cplusplus
}
#endif
