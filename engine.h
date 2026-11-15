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

void EngineStageFiles(const char *netPath, const char *bookPath);

// Depth-based search (no ELO limiting). Rodent V runs the Nimzoid
// personality permanently.
void EngineGo(const char *fen, int depth, int multipv, EngineResultBlock done);

int EngineLegalMoves(const char *fen, char *out, int maxMoves);

bool EngineFenLegal(const char *fen);

#ifdef __cplusplus
}
#endif
