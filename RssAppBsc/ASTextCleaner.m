#import "ASTextCleaner.h"

@implementation ASTextCleaner


+ (NSString *) cleanFromTagsWithRegexp:(NSString *)text{
    NSString *cleanedText;
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"<img.*\/>"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    
    cleanedText = [regex stringByReplacingMatchesInString:text
                                                  options:0
                                                    range:NSMakeRange(0, [text length])
                                             withTemplate:@""];
    
    regex = [NSRegularExpression regularExpressionWithPattern:@"<a.*>.*<\/a>"
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:&error];
    
    cleanedText = [regex stringByReplacingMatchesInString:cleanedText
                                                  options:0
                                                    range:NSMakeRange(0, [cleanedText length])
                                             withTemplate:@""];
    return cleanedText;
}

+ (NSString *)cleanFromTagsWithScanner:(NSString *)text{
    
    //wstawianie znakow specjalnych zamiast ich kodow
    NSString *tmpString = [text kv_decodeHTMLCharacterEntities];
    
    //czyszczenie z <TAGOW HTML>
    NSMutableString *cleanedText = [NSMutableString stringWithCapacity:[tmpString length]];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    scanner.charactersToBeSkipped = NULL;
    NSString *tempText = nil;
    
    while (![scanner isAtEnd])
    {
        [scanner scanUpToString:@"<" intoString:&tempText];
        
        if (tempText != nil)
            [cleanedText appendString:tempText];
        
        [scanner scanUpToString:@">" intoString:NULL];
        
        if (![scanner isAtEnd])
            [scanner setScanLocation:[scanner scanLocation] + 1];
        
        tempText = nil;
    }
    
    return cleanedText;
}

@end
