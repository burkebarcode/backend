package functions

import (
	"github.com/gin-gonic/gin"
)

func GetUserID(c *gin.Context) (string, bool) {
    v, ok := c.Get("user_id")
    if !ok {
        return "", false
    }
    id, ok := v.(string)
    return id, ok
}
